import SwiftUI

struct PairingView: View {
    @EnvironmentObject private var store: PlayerStore

    @State private var serverAddress = ""
    @State private var pin = ""
    @State private var isPairing = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case server
        case pin
    }

    var body: some View {
        HStack(spacing: 80) {
            VStack(alignment: .leading, spacing: 30) {
                BundledImageView(name: "tater-tube-logo-leaning-transparent")
                    .scaledToFit()
                    .frame(width: 610, alignment: .leading)

                Text("Your media, made for the big screen.")
                    .font(.system(size: 43, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Open Players on Tater Tube Server, create a pairing code, then enter it here.")
                    .font(.system(size: 27, weight: .regular, design: .rounded))
                    .foregroundStyle(TaterTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 700, alignment: .leading)

            VStack(alignment: .leading, spacing: 26) {
                Text("Connect to your server")
                    .font(.system(size: 36, weight: .bold, design: .rounded))

                TextField("Server address", text: $serverAddress)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .focused($focusedField, equals: .server)

                TextField("6-digit pairing code", text: $pin)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .pin)
                    .onChange(of: pin) { _, value in
                        pin = String(value.filter(\.isNumber).prefix(6))
                    }

                if let error = store.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundStyle(.orange)
                }

                HStack(spacing: 22) {
                    Button {
                        isPairing = true
                        Task {
                            await store.pair(serverAddress: serverAddress, pin: pin)
                            isPairing = false
                        }
                    } label: {
                        Label(isPairing ? "Connecting…" : "Pair", systemImage: "link")
                    }
                    .disabled(isPairing || serverAddress.isEmpty || pin.count != 6)

                    Button("Try Demo") { store.enterDemo() }
                }
                .buttonStyle(.borderedProminent)
                .tint(TaterTheme.orange)
            }
            .padding(54)
            .frame(width: 700)
            .taterGlass(cornerRadius: 32)
        }
        .padding(.horizontal, 90)
        .onAppear { focusedField = .server }
    }
}
