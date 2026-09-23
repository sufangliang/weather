import SwiftUI

struct SearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: SearchModel
    @FocusState private var focused: Bool

    var onPick: (Place) -> Void

    @MainActor
    init(onPick: @escaping (Place) -> Void) {
        self.onPick = onPick
        _model = State(initialValue: SearchModel())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                field
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if model.trimmed.isEmpty {
                            sectionTitle("常用城市")
                            ForEach(Place.shortcuts) { place in
                                row(place)
                            }
                        } else {
                            results
                        }
                    }
                    .padding(.bottom, 28)
                }
            }
            .background(WeatherTint.paper.top.ignoresSafeArea())
            .navigationTitle("搜尋地點")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(WeatherTint.paper.top, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                }
            }
            .onChange(of: model.query) { _, _ in
                model.schedule()
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var field: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(WeatherTint.paper.secondary)
            TextField("城市或地區", text: $model.query)
                .focused($focused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { model.submit() }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .onAppear { focused = true }
    }

    @ViewBuilder
    private var results: some View {
        switch model.phase {
        case .idle, .loading:
            ProgressView()
                .tint(WeatherTint.paper.ink)
                .frame(maxWidth: .infinity)
                .padding(.top, 36)
        case .failed(let message):
            VStack(spacing: 12) {
                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(WeatherTint.paper.ink)
                Button("再試一次") { model.submit() }
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 36)
        case .done:
            if model.results.isEmpty {
                Text("沒有「\(model.trimmed)」的結果")
                    .font(.system(size: 15))
                    .foregroundStyle(WeatherTint.paper.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
            } else {
                ForEach(model.results) { place in
                    row(place)
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(WeatherTint.paper.secondary)
            .padding(.horizontal, 22)
            .padding(.bottom, 4)
    }

    private func row(_ place: Place) -> some View {
        Button {
            onPick(place)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(place.name)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(WeatherTint.paper.ink)
                if !place.detail.isEmpty {
                    Text(place.detail)
                        .font(.system(size: 13))
                        .foregroundStyle(WeatherTint.paper.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.vertical, 13)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(WeatherTint.paper.ink.opacity(0.08))
                    .frame(height: 1)
                    .padding(.leading, 22)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SearchSheet { _ in }
}
