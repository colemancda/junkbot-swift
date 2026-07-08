import SwiftUI

@main
struct ModelStudioApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}

/// Sidebar list of every authored model + a live turntable preview of the selection. Adding a
/// model is just dropping a new file in Models/ and listing it in `ModelLibrary.all`.
struct ContentView: View {
  @State private var selection: Model.ID?

  private var selectedModel: Model? {
    ModelLibrary.all.first { $0.id == selection } ?? ModelLibrary.all.first
  }

  var body: some View {
    NavigationSplitView {
      List(ModelLibrary.all, selection: $selection) { model in
        Text(model.name).tag(model.id)
      }
      .navigationTitle("Models")
    } detail: {
      if let model = selectedModel {
        ModelSceneView(model: model)
          .ignoresSafeArea()
          .navigationTitle(model.name)
          .overlay(alignment: .bottomLeading) {
            Text("\(model.triangleCount) triangles")
              .font(.caption.monospaced())
              .padding(6)
              .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
              .padding()
          }
      } else {
        Text("Select a model")
      }
    }
  }
}
