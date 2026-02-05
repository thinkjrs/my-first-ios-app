//
//  ContentView.swift
//  My first app
//
//  Created by jason on 2/4/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse, animation: .bouncy.delay(0.5))
    private var items: [Item]

    @State private var showWashOptions = false
    @State private var hasScheduledWashes = false
    @State private var showScheduledWashes = false
    struct ScheduledWash: Identifiable, Equatable {
        let id = UUID()
        let date: Date
        let make: String
        let model: String
        let serviceLevel: String?
    }
    @State private var scheduledWashes: [ScheduledWash] = []

    var body: some View {
        NavigationSplitView {
            ZStack {
                Image("ducati-washed")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .offset(x: -240)
                    .clipped()
                    .ignoresSafeArea()
            }
            .safeAreaInset(edge: .bottom) {
                ZStack {
                    // Soft bottom fade for legibility over busy imagery
                    LinearGradient(
                        colors: [
                            Color(.systemBackground).opacity(0.0),
                            Color(.systemBackground).opacity(0.25)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 10)
                    .ignoresSafeArea()

                    Button {
                        if hasScheduledWashes {
                            showScheduledWashes = true
                        } else {
                            showWashOptions = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(hasScheduledWashes ? "📆  Scheduled Washes" : "🧼  Wash My Bike")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.black)
                            Image(systemName: "chevron.right")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.black)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 10)
                }
            }
            .sheet(isPresented: $showWashOptions) {
                WashOptionsView(
                    onScheduled: {
                        hasScheduledWashes = true
                    },
                    onScheduledDate: { date in
                        scheduledWashes.append(ScheduledWash(date: date, make: "Ducati", model: "Monster 937", serviceLevel: nil))
                        hasScheduledWashes = true
                    },
                    onImmediateScheduled: { make, model, service in
                        scheduledWashes.append(ScheduledWash(date: Date(), make: make, model: model, serviceLevel: service))
                        hasScheduledWashes = true
                    }
                )
            }
            .sheet(isPresented: $showScheduledWashes) {
                ScheduledWashesView(
                    washes: $scheduledWashes,
                    onAdd: { date in
                        scheduledWashes.append(ScheduledWash(date: date, make: "Ducati", model: "Monster 937", serviceLevel: nil))
                        hasScheduledWashes = !scheduledWashes.isEmpty
                    },
                    onDelete: { indexSet in
                        scheduledWashes.remove(atOffsets: indexSet)
                        hasScheduledWashes = !scheduledWashes.isEmpty
                    },
                    onScheduled: {
                        hasScheduledWashes = true
                    },
                    onScheduledDate: { date in
                        scheduledWashes.append(ScheduledWash(date: date, make: "Ducati", model: "Monster 937", serviceLevel: nil))
                        hasScheduledWashes = true
                    },
                    onImmediateScheduled: { make, model, service in
                        scheduledWashes.append(ScheduledWash(date: Date(), make: make, model: model, serviceLevel: service))
                        hasScheduledWashes = true
                    }
                )
            }
        } detail: {
            EmptyView()
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

private struct WashOptionsView: View {
    let onScheduled: () -> Void
    let onScheduledDate: (Date) -> Void
    let onImmediateScheduled: (_ make: String, _ model: String, _ service: String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showDatePicker = false
    @State private var scheduledDate = Date()
    @State private var showNowFlow = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Button("Now") {
                    showNowFlow = true
                }
                .font(.title.weight(.semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .background(Color(.systemBackground))
                .foregroundStyle(.primary)

                Button("Later") {
                    showDatePicker = true
                }
                .font(.title.weight(.semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .background(Color(.secondarySystemBackground))
                .foregroundStyle(.primary)
            }
            .ignoresSafeArea()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                VStack(spacing: 24) {
                    DatePicker(
                        "Select a date",
                        selection: $scheduledDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                }
                .navigationTitle("Schedule Wash")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            // Handle saving scheduledDate if needed
                            onScheduledDate(scheduledDate)
                            onScheduled()
                            dismiss()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showNowFlow) {
            NowFlowView(onCompleted: { make, model, service in
                onImmediateScheduled(make, model, service)
                onScheduled()
                showNowFlow = false
                dismiss()
            })
        }
    }
}

private struct NowFlowView: View {
    let onCompleted: ((_ make: String, _ model: String, _ service: String?) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var step: Int = 1
    @State private var locationStatus: String = "Unknown"
    @State private var make: String = "Ducati"
    @State private var model: String = "Monster 937"
    @State private var serviceLevel: String? = nil
    @State private var showConfetti = false

    private let models = ["Monster 937", "Panigale V2s"]

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case 1:
                    VStack(spacing: 20) {
                        Text("Share Your Location")
                            .font(.title2.weight(.semibold))
                        Text("We use your location to find the nearest washer.")
                            .foregroundStyle(.secondary)
                        Button("Get Current Location") {
                            // Placeholder: integrate Core Location here
                            locationStatus = "Location captured"
                            step = 2
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .padding(.top, 8)
                        Text(locationStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding()
                case 2:
                    Form {
                        Section(header: Text("Make")) {
                            Picker("Make", selection: $make) {
                                Text("Ducati").tag("Ducati")
                            }
                            .pickerStyle(.menu)
                        }
                        Section(header: Text("Model")) {
                            Picker("Model", selection: $model) {
                                ForEach(models, id: \.self) { m in
                                    Text(m).tag(m)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                case 3:
                    VStack(spacing: 16) {
                        Text("Select Service Level")
                            .font(.title2.weight(.semibold))
                        Button("Basic") { serviceLevel = "Basic"; step = 4 }
                            .buttonStyle(.borderedProminent)
                        Button("Premium") { serviceLevel = "Premium"; step = 4 }
                            .buttonStyle(.borderedProminent)
                        Button("Ultimate") { serviceLevel = "Ultimate"; step = 4 }
                            .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    .padding()
                case 4:
                    VStack(spacing: 16) {
                        Text("Confirm Your Wash")
                            .font(.title2.weight(.semibold))
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Make: \(make)")
                            Text("Model: \(model)")
                            if let serviceLevel {
                                Text("Service Level: \(serviceLevel)")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )

                        Button("Confirm") {
                            // TODO: Submit request here
                            withAnimation(.spring) { showConfetti = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                // Dismiss this sheet, then notify parent to dismiss itself
                                dismiss()
                                onCompleted?(make, model, serviceLevel)
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Back") {
                            step = 3
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                    .padding()
                default:
                    EmptyView()
                }
            }
            .navigationTitle(titleForStep(step))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        if step > 1 {
                            Button("Back") { step -= 1 }
                        }
                        Button(step < 4 ? "Next" : "Done") {
                            if step < 4 { step += 1 } else { dismiss() }
                        }
                        .disabled(step == 2 && make.isEmpty)
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            if showConfetti {
                ConfettiOverlay()
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .ignoresSafeArea()
            }
        }
    }

    private func titleForStep(_ step: Int) -> String {
        switch step {
        case 1: return "Location"
        case 2: return "Bike Details"
        case 3: return "Service Level"
        case 4: return "Confirm"
        default: return ""
        }
    }
}

private struct ConfettiOverlay: View {
    @State private var animate = false
    private let symbols = ["🎉", "🎊", "✨", "🥳", "⭐️"]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<30, id: \.self) { i in
                    let x = CGFloat.random(in: 0...proxy.size.width)
                    let size = CGFloat.random(in: 18...34)
                    let delay = Double.random(in: 0...0.6)
                    let duration = Double.random(in: 1.2...1.8)
                    let symbol = symbols.randomElement() ?? "🎉"

                    Text(symbol)
                        .font(.system(size: size))
                        .position(x: x, y: animate ? proxy.size.height + 40 : -40)
                        .rotationEffect(.degrees(animate ? Double.random(in: 180...540) : 0))
                        .opacity(animate ? 0.0 : 1.0)
                        .animation(.easeIn(duration: duration).delay(delay), value: animate)
                }
            }
            .onAppear { animate = true }
        }
    }
}

private struct ScheduledWashesView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var washes: [ContentView.ScheduledWash]
    let onAdd: (Date) -> Void
    let onDelete: (IndexSet) -> Void
    let onScheduled: () -> Void
    let onScheduledDate: (Date) -> Void
    let onImmediateScheduled: (_ make: String, _ model: String, _ service: String?) -> Void
    @State private var showOptions = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(washes) { wash in
                    VStack(alignment: .leading) {
                        Text("\(wash.make) \(wash.model)")
                            .font(.headline)
                        HStack {
                            if let service = wash.serviceLevel {
                                Text(service)
                            }
                            Spacer()
                            Text(wash.date, style: .date)
                            Text(wash.date, style: .time)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .onDelete(perform: onDelete)
            }
            .navigationTitle("Scheduled Washes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showOptions = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showOptions) {
                WashOptionsView(
                    onScheduled: onScheduled,
                    onScheduledDate: onScheduledDate,
                    onImmediateScheduled: onImmediateScheduled
                )
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

