import GeistData
import SwiftUI

/// The generic key/value viewer for a Stripe object (decision 0012).
/// Either built from an explicit field list or from a raw JSON tree.
struct ObjectDetailView: View {
  private let fields: [(String, String)]
  private let title: String

  init(fields: [(String, String)], title: String) {
    self.fields = fields
    self.title = title
  }

  /// Renders every top-level field of a raw object.
  init(json: StripeJSON, title: String = "Object") {
    self.init(fields: json.flattened().map { ($0.key, $0.value) }, title: title)
  }

  var body: some View {
    List {
      ForEach(fields, id: \.0) { field in
        HStack(alignment: .firstTextBaseline) {
          Text(field.0)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(minWidth: 120, alignment: .leading)
          Spacer()
          Text(field.1)
            .font(.callout)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 360, alignment: .trailing)
            .textSelection(.enabled)
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
  }
}
