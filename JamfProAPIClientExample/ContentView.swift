//
//  ContentView.swift
//  JamfProAPIClientExample
//
//  Created by Bryson Tyrrell on 8/26/24.
//

import SwiftUI

struct ContentView: View {
    @State private var showSetupSheet = false
    @State private var showInvalidSettingsAlert = false
    
    @State private var client: JamfProAPIClient?
    
    @State private var jamfProVersion = ""
    @State private var computerSearchResults: Components.Schemas.ComputerInventorySearchResults?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Version:")
                            .font(.headline)
                        Spacer()
                        Text(jamfProVersion)
                            .progressViewStyle(.circular)
                    }
                    
                    if client != nil {
                        Button {
                            Task {
                                do {
                                    let accessToken = try await client?.AccessToken()
                                    UIPasteboard.general.string = accessToken
                                } catch {
                                    print(error.localizedDescription)
                                }
                            }
                        } label: {
                            HStack {
                                Text("Get Access Token")
                                Image(systemName: "doc.on.doc")
                            }
                        }
                    }
                }
                
                Section {
                    HStack {
                        Text("Total computers:")
                            .font(.headline)
                        Spacer()
                        Text(String(computerSearchResults?.totalCount ?? 0))
                    }
                }
                
                Section {
                    if let computerResults = computerSearchResults?.results {
                        ForEach(computerResults.sorted()) { computer in
                            VStack(alignment: .leading) {
                                Text("\(computer.general?.name ?? "Unknown") | \(computer.id!)")
                                    .font(.headline)
                                Text(computer.general?.managementId ?? "Unknown")
                                    .font(.caption)
                                    .textSelection(.enabled)
                                HStack {
                                    Text("Assigned User:")
                                    Text(computer.userAndLocation?.username ?? "Unkown")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(client?.hostname ?? "Jamf Pro API Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Setup", systemImage: "gear") {
                    showSetupSheet.toggle()
                }
            }
            .sheet(isPresented: $showSetupSheet) {
                SetupView(client: $client)
            }
            .task(id: client) {
                do {
                    jamfProVersion = try await client?.api.JamfProVersionGetV1().ok.body.json.version ?? "Unknown"
                    
                    computerSearchResults = try await client?.ComputerInventoryGetV1AllPages(
                        query: .init(
                            section: [.GENERAL, .USER_AND_LOCATION]
                        )
                    )
                } catch {
                    print(error.localizedDescription)
                    showInvalidSettingsAlert.toggle()
                }
            }
            .alert("Invalid Settings", isPresented: $showInvalidSettingsAlert) {
                Button("OK", role: .cancel) {
                    client = nil
                }
            } message: {
                Text("Requests failed. Try client setup again.")
            }
            .dialogIcon(Image(systemName: "exclamationmark.triangle"))
        }
    }
}

#Preview {
    ContentView()
}
