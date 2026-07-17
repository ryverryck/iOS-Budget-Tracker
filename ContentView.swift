//
//  ContentView.swift
//  GOBudget Tracker
//
//  Created by Ryver Ryckeghem on 11/24/25.
//

import SwiftUI
import Combine
import Charts // REQUIRED for the Graphs

// MARK: - 1. DATA MODELS
struct ExpenseItem: Identifiable, Codable {
    let id: UUID
    let amount: Double
    let merchant: String
    let category: String
    let date: Date
}

// MARK: - 2. THEME
extension Color {
    static let neonGreen = Color(red: 0.2, green: 1.0, blue: 0.4)
    static let darkBg = Color(red: 0.05, green: 0.05, blue: 0.07)
    static let cardBg = Color(red: 0.1, green: 0.1, blue: 0.12)
}

// MARK: - 3. LOGIC STORE
class ExpenseStore: ObservableObject {
    @Published var expenses: [ExpenseItem] = [] { didSet { save() } }
    @Published var monthlyBudget: Double = 500.0 { didSet { saveSettings() } }
    @Published var username: String = "" { didSet { saveSettings() } }
    @Published var isOnboarded: Bool = false { didSet { saveSettings() } }

    init() {
        load()
        loadSettings()
    }
    
    // Actions
    func add(amount: Double, merchant: String, category: String) {
        let newItem = ExpenseItem(id: UUID(), amount: amount, merchant: merchant, category: category, date: Date())
        expenses.insert(newItem, at: 0)
    }
    
    func delete(at offsets: IndexSet) {
        expenses.remove(atOffsets: offsets)
    }
    
    // Stats
    var totalSpent: Double { expenses.reduce(0) { $0 + $1.amount } }
    var remaining: Double { monthlyBudget - totalSpent }
    var progress: Double { min(totalSpent / max(monthlyBudget, 1.0), 1.0) }
    
    // "Wrapped" Stats
    var biggestPurchase: ExpenseItem? { expenses.max(by: { $0.amount < $1.amount }) }
    
    var topCategory: (String, Double)? {
        let grouped = Dictionary(grouping: expenses, by: { $0.category })
        let amounts = grouped.mapValues { items in items.reduce(0) { $0 + $1.amount } }
        return amounts.max(by: { $0.value < $1.value })
    }
    
    var dailySpending: [(String, Double)] {
        let grouped = Dictionary(grouping: expenses, by: { $0.date.formatted(.dateTime.weekday()) })
        return grouped.map { ($0.key, $0.value.reduce(0) { $0 + $1.amount }) }.sorted { $0.1 > $1.1 }
    }

    // Persistence
    private func save() {
        if let encoded = try? JSONEncoder().encode(expenses) {
            UserDefaults.standard.set(encoded, forKey: "vibe_expenses")
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: "vibe_expenses"),
           let decoded = try? JSONDecoder().decode([ExpenseItem].self, from: data) {
            expenses = decoded
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(monthlyBudget, forKey: "vibe_budget")
        UserDefaults.standard.set(username, forKey: "vibe_username")
        UserDefaults.standard.set(isOnboarded, forKey: "vibe_onboarded")
    }
    
    private func loadSettings() {
        monthlyBudget = UserDefaults.standard.double(forKey: "vibe_budget")
        if monthlyBudget == 0 { monthlyBudget = 500 }
        username = UserDefaults.standard.string(forKey: "vibe_username") ?? ""
        isOnboarded = UserDefaults.standard.bool(forKey: "vibe_onboarded")
    }
}

// MARK: - 4. MAIN VIEWS
struct ContentView: View {
    @StateObject private var store = ExpenseStore()
    @State private var showAddSheet = false
    @State private var showRecap = false
    
    var body: some View {
        ZStack {
            Color.darkBg.ignoresSafeArea()
            
            if !store.isOnboarded {
                OnboardingView(store: store)
            } else {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Text("Hi, \(store.username)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { showRecap = true }) {
                            Text("Vibe Recap")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.neonGreen)
                                .foregroundColor(.black)
                                .cornerRadius(20)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Dashboard Card
                    VStack(spacing: 15) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("TOTAL SPENT")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("$\(store.totalSpent, specifier: "%.2f")")
                                    .font(.system(size: 32, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("REMAINING")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("$\(store.remaining, specifier: "%.2f")")
                                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                                    .foregroundColor(store.remaining < 0 ? .red : .neonGreen)
                            }
                        }
                        
                        // Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .frame(width: geo.size.width, height: 10)
                                    .foregroundColor(Color.white.opacity(0.1))
                                    .cornerRadius(5)
                                Rectangle()
                                    .frame(width: geo.size.width * store.progress, height: 10)
                                    .foregroundColor(.neonGreen)
                                    .cornerRadius(5)
                            }
                        }
                        .frame(height: 10)
                        
                        Text("\(Int(store.progress * 100))% of budget used")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.cardBg)
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    // Transaction List
                    VStack(alignment: .leading) {
                        HStack {
                            Text("RECENT TRANSACTIONS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                            Spacer()
                            Button(action: { showAddSheet = true }) {
                                Image(systemName: "plus")
                                    .font(.title2)
                                    .foregroundColor(.neonGreen)
                            }
                        }
                        .padding(.horizontal)
                        
                        List {
                            ForEach(store.expenses) { item in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(item.merchant)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text(item.category)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Text("$\(item.amount, specifier: "%.2f")")
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                                .listRowBackground(Color.cardBg)
                            }
                            .onDelete(perform: store.delete)
                        }
                        .scrollContentBackground(.hidden)
                        .listStyle(.plain)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddExpenseView(store: store)
        }
        .fullScreenCover(isPresented: $showRecap) {
            RecapView(store: store)
        }
        // DEEP LINK HANDLER
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }
    
    func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else { return }
        
        var amount: Double = 0.0
        var merchant: String = "Unknown"
        var category: String = "General"
        
        for item in queryItems {
            if item.name == "amount", let val = item.value { amount = Double(val) ?? 0.0 }
            if item.name == "merchant", let val = item.value { merchant = val }
            if item.name == "category", let val = item.value { category = val }
        }
        
        if amount > 0 {
            store.add(amount: amount, merchant: merchant, category: category)
        }
    }
}

// MARK: - 5. SUB-VIEWS

struct OnboardingView: View {
    @ObservedObject var store: ExpenseStore
    @State private var tempName = ""
    @State private var tempBudget = ""
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            Text("Vibe\nTracker")
                .font(.system(size: 50, weight: .black, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            
            VStack(spacing: 15) {
                TextField("Your Name", text: $tempName)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                
                TextField("Monthly Budget", text: $tempBudget)
                    .keyboardType(.decimalPad)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            
            Button(action: {
                if !tempName.isEmpty, let budget = Double(tempBudget) {
                    store.username = tempName
                    store.monthlyBudget = budget
                    withAnimation {
                        store.isOnboarded = true
                    }
                }
            }) {
                Text("START")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.neonGreen)
                    .foregroundColor(.black)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .disabled(tempName.isEmpty || tempBudget.isEmpty)
            .opacity(tempName.isEmpty || tempBudget.isEmpty ? 0.5 : 1.0)
            
            Spacer()
        }
        .background(Color.darkBg)
    }
}

struct AddExpenseView: View {
    @ObservedObject var store: ExpenseStore
    @Environment(\.dismiss) var dismiss
    
    @State private var amount = ""
    @State private var merchant = ""
    @State private var category = "Food"
    
    let categories = ["Food", "Transport", "Shopping", "Entertainment", "Bills", "Other"]
    
    var body: some View {
        ZStack {
            Color.darkBg.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("New Transaction")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top)
                
                TextField("$0.00", text: $amount)
                    .font(.system(size: 40, weight: .bold))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.neonGreen)
                
                VStack(spacing: 15) {
                    TextField("Merchant (e.g. Starbucks)", text: $merchant)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(categories, id: \.self) { cat in
                                Button(action: { category = cat }) {
                                    Text(cat)
                                        .padding(.horizontal, 15)
                                        .padding(.vertical, 8)
                                        .background(category == cat ? Color.neonGreen : Color.white.opacity(0.1))
                                        .foregroundColor(category == cat ? .black : .white)
                                        .cornerRadius(20)
                                }
                            }
                        }
                    }
                }
                .padding()
                
                Button(action: {
                    if let amt = Double(amount), !merchant.isEmpty {
                        store.add(amount: amt, merchant: merchant, category: category)
                        dismiss()
                    }
                }) {
                    Text("ADD")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.neonGreen)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                }
                .padding()
                
                Spacer()
            }
        }
    }
}

// MARK: - 6. WRAPPED / RECAP VIEW
struct RecapView: View {
    @ObservedObject var store: ExpenseStore
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.darkBg.ignoresSafeArea()
            
            TabView {
                // SLIDE 1: Intro
                VStack {
                    Text("Your Weekly\nRecap")
                        .font(.system(size: 50, weight: .black))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text("Swipe to see your vibe >>>")
                        .foregroundColor(.gray)
                        .padding(.top)
                }
                
                // SLIDE 2: Total
                VStack(spacing: 20) {
                    Text("This week you spent")
                        .foregroundColor(.gray)
                    Text("$\(store.totalSpent, specifier: "%.2f")")
                        .font(.system(size: 60, weight: .heavy, design: .monospaced))
                        .foregroundColor(.neonGreen)
                    Text("across \(store.expenses.count) transactions")
                        .foregroundColor(.white)
                }
                
                // SLIDE 3: Top Category
                if let top = store.topCategory {
                    VStack(spacing: 20) {
                        Text("Your Vibe Was")
                            .foregroundColor(.gray)
                        Text(top.0)
                            .font(.system(size: 50, weight: .black))
                            .foregroundColor(.white)
                        Text("$\(top.1, specifier: "%.2f")")
                            .font(.title)
                            .foregroundColor(.neonGreen)
                    }
                }
                
                // SLIDE 4: Daily Chart
                VStack {
                    Text("Spending Flow")
                        .font(.headline)
                        .foregroundColor(.white)
                    Chart {
                        ForEach(store.dailySpending, id: \.0) { item in
                            BarMark(
                                x: .value("Day", item.0),
                                y: .value("Amount", item.1)
                            )
                            .foregroundStyle(Color.neonGreen)
                        }
                    }
                    .frame(height: 300)
                    .padding()
                }
                
                // SLIDE 5: Close
                VStack {
                    Text("Stay on track.")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Button("Back to Dashboard") {
                        dismiss()
                    }
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(20)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }
}
