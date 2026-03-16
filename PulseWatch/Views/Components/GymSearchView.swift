import SwiftUI
import MapKit

/// 健身房地址搜索视图 — 自动补全 + 地图确认
struct GymSearchView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelected: (String, Double, Double) -> Void  // (name, lat, lon)

    @State private var searchText = ""
    @State private var completer = LocationSearchCompleter()
    @State private var selectedResult: MKLocalSearchCompletion?
    @State private var confirmedPlace: MKMapItem?
    @State private var isResolving = false
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索框
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundStyle(PulseTheme.textTertiary)

                    TextField(String(localized: "搜索健身房"), text: $searchText)
                        .font(PulseTheme.bodyFont)
                        .foregroundStyle(PulseTheme.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: searchText) { _, newValue in
                            completer.search(query: newValue)
                            confirmedPlace = nil
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            confirmedPlace = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(PulseTheme.textTertiary)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                        .fill(PulseTheme.surface)
                )
                .padding(.horizontal, PulseTheme.spacingM)
                .padding(.top, PulseTheme.spacingS)

                if let place = confirmedPlace {
                    // 确认模式 — 显示地图 + 确认按钮
                    confirmationView(place: place)
                } else if !completer.results.isEmpty && !searchText.isEmpty {
                    // 搜索结果列表
                    searchResultsList
                } else if searchText.isEmpty {
                    // 空状态
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(PulseTheme.textTertiary.opacity(0.5))
                        Text("搜索你常去的健身房")
                            .font(PulseTheme.bodyFont)
                            .foregroundStyle(PulseTheme.textTertiary)
                        Spacer()
                    }
                } else if completer.isSearching {
                    ProgressView()
                        .tint(PulseTheme.accent)
                        .padding(.top, 40)
                    Spacer()
                } else {
                    Spacer()
                }
            }
            .background(PulseTheme.background)
            .navigationTitle("添加健身房")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(PulseTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - 搜索结果列表

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(completer.results, id: \.self) { result in
                    Button {
                        resolvePlace(result)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(PulseTheme.accent)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(PulseTheme.bodyFont)
                                    .foregroundStyle(PulseTheme.textPrimary)
                                    .lineLimit(1)

                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(PulseTheme.captionFont)
                                        .foregroundStyle(PulseTheme.textTertiary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            if isResolving && selectedResult == result {
                                ProgressView()
                                    .tint(PulseTheme.accent)
                                    .scaleEffect(0.7)
                            }
                        }
                        .padding(.horizontal, PulseTheme.spacingM)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .overlay(PulseTheme.border)
                        .padding(.leading, 50)
                }
            }
        }
    }

    // MARK: - 确认视图（地图 + 按钮）

    private func confirmationView(place: MKMapItem) -> some View {
        VStack(spacing: 0) {
            // 地图预览
            Map(position: $cameraPosition) {
                Marker(
                    place.name ?? String(localized: "健身房"),
                    coordinate: place.placemark.coordinate
                )
                .tint(PulseTheme.accent)
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous))
            .padding(.horizontal, PulseTheme.spacingM)
            .padding(.top, PulseTheme.spacingM)
            .allowsHitTesting(false)

            // 地点信息
            VStack(alignment: .leading, spacing: 6) {
                Text(place.name ?? String(localized: "健身房"))
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)

                if let address = place.placemark.formattedAddress {
                    Text(address)
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PulseTheme.spacingM)
            .padding(.top, PulseTheme.spacingM)

            Spacer()

            // 确认按钮
            Button {
                let coord = place.placemark.coordinate
                let name = place.name ?? String(localized: "健身房")
                onSelected(name, coord.latitude, coord.longitude)
                dismiss()
            } label: {
                Text("确认选择")
                    .font(PulseTheme.bodyFont.weight(.semibold))
                    .foregroundStyle(PulseTheme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                            .fill(PulseTheme.accent)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, PulseTheme.spacingM)
            .padding(.bottom, PulseTheme.spacingM)
        }
    }

    // MARK: - 解析地点

    private func resolvePlace(_ completion: MKLocalSearchCompletion) {
        selectedResult = completion
        isResolving = true

        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)

        search.start { response, error in
            isResolving = false
            guard let item = response?.mapItems.first else { return }

            confirmedPlace = item
            let coord = item.placemark.coordinate
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 500,
                longitudinalMeters: 500
            ))
        }
    }
}

// MARK: - Location Search Completer

@Observable
final class LocationSearchCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var results: [MKLocalSearchCompletion] = []
    var isSearching = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .pointOfInterest
    }

    func search(query: String) {
        guard !query.isEmpty else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // 优先显示健身房相关结果
        results = completer.results
        isSearching = false
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        isSearching = false
    }
}

// MARK: - CLPlacemark Extension

extension CLPlacemark {
    var formattedAddress: String? {
        [subThoroughfare, thoroughfare, locality, administrativeArea]
            .compactMap { $0 }
            .joined(separator: " ")
            .nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
