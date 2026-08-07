/// The registry of every authored model. To add a model: create a file under Models/ with an
/// `enum FooModel { static let model = Model("Foo") { ... } }`, then add `FooModel.model` here.
enum ModelLibrary {
  static let all: [Model] = [
    BrickModel.model,
    JunkbotModel.model,
    GearbotModel.model,
    ClimbbotModel.model,
    FlybotModel.model,
    EyebotModel.model,
    BinModel.model,
    CrateModel.model,
    FireModel.model,
    FanModel.model,
    SwitchModel.model,
    PipeModel.model,
    ShieldModel.model,
    TeleportModel.model,
    LaserModel.model,
    JumpModel.model,
  ]
}
