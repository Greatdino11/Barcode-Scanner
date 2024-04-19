import SwiftUI
import CodeScanner
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth

struct Product: Hashable, Identifiable, Codable {
    @DocumentID var id: String?
    let code: String
    let productName: String
    let nutriScore: String
    let apiResponse: String
    let timestamp: Timestamp
}

struct Home: View {
    @State private var isPresentingScanner = false
    @State private var scannedCode: String = "Scan a code to get started."
    @State private var productName: String = ""
    @State private var nutriScore: String = ""
    @State private var jsonResults: String = ""
    @State private var db = Firestore.firestore()
    @State private var scannedProducts: [Product] = []
    @AppStorage("log_status") private var logStatus: Bool = false

    var body: some View {
        VStack {
            Text(jsonResults)
            Button("Scan Barcode") {
                isPresentingScanner = true
            }

            Button("Fetch Scanned Products") {
                fetchScannedProducts()
            }
            
            List(scannedProducts) { product in
                Text("Product: \(product.productName)")
                Text("NutriScore: \(product.nutriScore)")
                Text(product.apiResponse)
                Spacer()
            }
            .frame(height: 650)
            
            NavigationStack {
                Button("Logout") {
                    do {
                        try Auth.auth().signOut()
                        logStatus = false
                    } catch {
                        print("Error signing out: \(error.localizedDescription)")
                    }
                }
            }
        }
        .padding()
        .sheet(isPresented: $isPresentingScanner) {
            scannerSheet
        }
    }

    var scannerSheet: some View {
        CodeScannerView(
            codeTypes: [.qr, .gs1DataBar, .ean8, .ean13, .code128, .upce, .itf14, .code39, .code93, .codabar],
            completion: { result in
                if case .success(let code) = result {
                    scannedCode = code.string
                    fetchProductData(for: code.string)
                    isPresentingScanner = false
                }
            }
        )
    }

    func fetchProductData(for code: String) {
        productName = ""
        nutriScore = ""
        guard let url = URL(string: "https://world.openfoodfacts.net/api/v2/product/\(code)?fields=product_name,nutriscore_data") else {
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }

            if let data = data {
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])
                    self.jsonResults = "API Response: \(json)"

                    if let dictionary = json as? [String: Any],
                       let productDict = dictionary["product"] as? [String: Any] {
                        if let productName = productDict["product_name"] as? String,
                           let nutriscoreData = productDict["nutriscore_data"] as? [String: Any],
                           let grade = nutriscoreData["grade"] as? String {
                            DispatchQueue.main.async {
                                self.productName = productName
                                self.nutriScore = "NutriScore: " + String(grade.uppercased())
                                saveToFirestore(code: code, productName: productName, nutriScore: grade.uppercased(), apiResponse: self.jsonResults)
                            }
                        }
                        else if let productName = productDict["product_name"] as? String {
                             DispatchQueue.main.async {
                                 self.productName = productName
                                 self.nutriScore = "NutriScore: N/A"
                                 saveToFirestore(code: code, productName: productName, nutriScore: "N/A", apiResponse: self.jsonResults)
                             }
                         } else {
                            print("Nutriscore data not found in response")
                        }
                    } else {
                        print("Failed to parse JSON response")
                    }
                } catch {
                    print("Error: \(error.localizedDescription)")
                }
            }
        }.resume()
    }

    func saveToFirestore(code: String, productName: String, nutriScore: String, apiResponse: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No user is currently signed in")
            return
        }

        let product = Product(code: code, productName: productName, nutriScore: nutriScore, apiResponse: apiResponse, timestamp: Timestamp(date: Date()))

        do {
            try db.collection("users").document(userId).collection("scannedProducts").addDocument(from: product) { error in
                if let error = error {
                    print("Error saving to Firestore: \(error.localizedDescription)")
                } else {
                    print("Scanned data saved to Firestore successfully")
                }
            }
        } catch {
            print("Error saving to Firestore: \(error.localizedDescription)")
        }
    }

    func fetchScannedProducts() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No user is currently signed in")
            return
        }

        db.collection("users").document(userId).collection("scannedProducts")
            .order(by: "timestamp", descending: true)
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error getting scanned products: \(error.localizedDescription)")
                } else {
                    scannedProducts = querySnapshot?.documents.compactMap { document in
                        try? document.data(as: Product.self)
                    } ?? []
                }
            }
    }
}
