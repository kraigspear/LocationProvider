//
//  FindLocationView.swift
//  TestApp
//
//  Created by Kraig Spear on 1/26/25.
//

import LocationProvider
import os
import SwiftUI

private let logger = os.Logger(subsystem: "com.spearware.locationprovider.testapp", category: "contentView")

struct FindLocationView: View {
    @State private var model: Model

    init(state: FindLocationView.Model.State = .init()) {
        _model = .init(initialValue: .init(state: state))
    }

    var body: some View {
        VStack(spacing: 20) {
            switch model.state.innerView {
            case .idle:
                FindLocationButton(model: model)
            case .loading:
                ProgressView("Finding location...")
                    .progressViewStyle(.circular)
            case let .loaded(location):
                LocationInfoView(location: location)
            case let .error(message):
                ErrorView(message: message)
            }
        }.environment(model)
    }

    struct FindLocationButton: View {
        let model: FindLocationView.Model

        var body: some View {
            Button(action: {
                Task {
                    await model.fetchCurrentLocation()
                }
            }) {
                Text("Get Location")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }

    struct ErrorView: View {
        @Environment(FindLocationView.Model.self) private var model

        let message: String
        var body: some View {
            VStack(spacing: 16) {
                Text(message)
                    .font(.title3)
                    .foregroundStyle(.red)

                Button(action: {
                    Task {
                        await openLocationSettings()
                    }
                }) {
                    Text("Open Location Settings")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Button(action: {
                    model.reset()
                }) {
                    Text("Reset")
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
    }
}

extension FindLocationView {
    @MainActor
    @Observable
    final class Model {
        enum InnerView: Equatable {
            case idle
            case loading
            case loaded(GPSLocation)
            case error(String)
        }

        struct State: Equatable {
            var innerView = InnerView.idle
        }

        private(set) var state: State

        init(state: State = .init()) {
            self.state = state
        }

        // MARK: - Action(s)

        func fetchCurrentLocation() async {
            do {
                state.innerView = .loading

                logger.debug("Finding location")
                let gpsLocation = try await LocationProvider().gpsLocation()
                logger.debug("Location found: \(gpsLocation)")

                state.innerView = .loaded(gpsLocation)
            } catch {
                logger.error("Error fetching location: \(error)")
                state.innerView = .error(error.localizedDescription)
            }
        }

        func reset() {
            state.innerView = .idle
        }
    }
}

#Preview {
    FindLocationView()
}
