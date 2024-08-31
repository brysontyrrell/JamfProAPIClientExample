//
//  SetupView.swift
//  JamfProAPIClientExample
//
//  Created by Bryson Tyrrell on 8/30/24.
//

import SwiftUI

struct SetupView: View {
    @Environment(\.dismiss) var dismiss
    
    @Binding var client: JamfProAPIClient?
    
    @State private var hostname = ""
    @State private var clientID = ""
    @State private var clientSecret = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Hostname")
                            .font(.headline)
                        Spacer()
                        TextField("my.jamf.pro", text: $hostname)
                            .autocorrectionDisabled()
                            .autocapitalization(.none)
                            .keyboardType(.webSearch)
                            .multilineTextAlignment(.trailing)
                            .padding(.leading)
                    }
                    
                    HStack {
                        Text("Client ID")
                            .font(.headline)
                        Spacer()
                        TextField("abc123", text: $clientID)
                            .autocorrectionDisabled()
                            .autocapitalization(.none)
                            .multilineTextAlignment(.trailing)
                            .padding(.leading)
                    }
                    
                    HStack {
                        Text("Client Secret")
                            .font(.headline)
                        Spacer()
                        SecureField("******", text: $clientSecret)
                            .autocorrectionDisabled()
                            .autocapitalization(.none)
                            .multilineTextAlignment(.trailing)
                            .padding(.leading)
                    }
                }
            }
            .navigationTitle("Client Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        client = JamfProAPIClient(
                            hostname: hostname,
                            clientID: clientID,
                            clientSecret: clientSecret
                        )
                        
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var client: JamfProAPIClient?
    SetupView(client: $client)
}
