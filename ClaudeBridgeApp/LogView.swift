import SwiftUI

struct LogView: View {
    var proxy: ProxyManager

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Proxy Logs")
                    .font(.headline)
                Spacer()
                Button {
                    proxy.clearLogs()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Log content
            ScrollViewReader { scrollProxy in
                ScrollView {
                    if proxy.logs.isEmpty {
                        Text("No logs yet.")
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .foregroundStyle(.secondary)
                    } else {
                        Text(verbatim: proxy.logs)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .textSelection(.enabled)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .onChange(of: proxy.logs) {
                    withAnimation {
                        scrollProxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
        .frame(minWidth: 550, idealWidth: 650, minHeight: 350, idealHeight: 450)
        .navigationTitle("Logs")
    }
}

