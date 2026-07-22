//
//  CanvasView.swift
//  Goddard
//
//  Stub canvas: shows the optimizer's live grayscale render over a black
//  background. Placeholder for the Metal splat view that replaces it next.
//

import SwiftUI

struct CanvasView: View {
    @EnvironmentObject var fViewModel: TgoddardViewModel

    var body: some View {
        ZStack {
            Color.black
            if let image = fViewModel.fPreviewImage {
                Image(decorative: image, scale: 1.0)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(24)
            } else {
                Text("Canvas — press Reset")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
