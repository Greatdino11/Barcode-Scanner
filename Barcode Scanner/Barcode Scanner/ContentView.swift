import SwiftUI
import Firebase

struct ContentView: View {
    
    @AppStorage("log_status") private var logStatus: Bool = false
    
    var body: some View {
        if logStatus {
            Home()
        } else {
            Login()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
