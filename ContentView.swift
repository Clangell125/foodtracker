import SwiftUI
import UserNotifications

struct FoodItem: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var expirationDate: Date
    
    init(id: UUID = UUID(), name: String, expirationDate: Date) {
        self.id = id
        self.name = name
        self.expirationDate = expirationDate
    }
}

struct ContentView: View {
    @State private var foodItems: [FoodItem] = []
    @State private var groceryItems: [String] = []
    @State private var newItemName = ""
    @State private var newItemDate = Date()
    @State private var newGroceryItem = ""
    @State private var selectedGroceryItem: String?
    @State private var groceryItemExpirationDate: Date = Date()
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Add a new food item")
                    .font(.headline)
                    .padding(.horizontal)
                
                TextField("Enter food name", text: $newItemName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                DatePicker("Expiration Date", selection: $newItemDate, displayedComponents: .date)
                    .padding(.horizontal)
                
                Button(action: {
                    guard !newItemName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let item = FoodItem(name: newItemName, expirationDate: newItemDate)
                    foodItems.append(item)
                    scheduleNotification(for: item)
                    saveFoodItems()
                    newItemName = ""
                }) {
                    Text("Add Item")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
                
                Divider()
                
                Text("Grocery List")
                    .font(.headline)
                    .padding(.horizontal)
                
                HStack {
                    TextField("Add grocery item", text: $newGroceryItem)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: {
                        guard !newGroceryItem.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        groceryItems.append(newGroceryItem)
                        saveGroceryItems()
                        newGroceryItem = ""
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal)
                
                List {
                    ForEach(groceryItems, id: \ .self) { item in
                        HStack {
                            Text(item)
                            Spacer()
                            Button("Bought") {
                                selectedGroceryItem = item
                                groceryItemExpirationDate = Date()
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .onDelete(perform: deleteGroceryItems)
                }
                .listStyle(PlainListStyle())
                
                if let selectedItem = selectedGroceryItem {
                    VStack(spacing: 10) {
                        Text("Set Expiration Date for \(selectedItem)")
                            .font(.headline)
                        DatePicker("Expiration Date", selection: $groceryItemExpirationDate, displayedComponents: .date)
                            .datePickerStyle(GraphicalDatePickerStyle())
                            .padding()
                        Button("Save Expiration Date") {
                            let newFood = FoodItem(name: selectedItem, expirationDate: groceryItemExpirationDate)
                            foodItems.append(newFood)
                            scheduleNotification(for: newFood)
                            if let index = groceryItems.firstIndex(of: selectedItem) {
                                groceryItems.remove(at: index)
                            }
                            saveFoodItems()
                            saveGroceryItems()
                            selectedGroceryItem = nil
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                }
            }
            
            .onAppear {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { success, error in
                    if success {
                        print("Notifications allowed!")
                    } else if let error = error {
                        print(error.localizedDescription)
                    }
                }
                loadFoodItems()
                loadGroceryItems()
            }
        } detail: {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(foodItems) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Spacer()
                                Button(action: {
                                    if let index = foodItems.firstIndex(of: item) {
                                        foodItems.remove(at: index)
                                        saveFoodItems()
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                            Text(item.name)
                                .font(.headline)
                            Text("Expires on \(item.expirationDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(expirationColor(for: item))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("All Food Items")
        }
    }
    
    func expirationColor(for item: FoodItem) -> Color {
        let daysUntilExpiration = Calendar.current.dateComponents([.day], from: Date(), to: item.expirationDate).day ?? 0
        switch daysUntilExpiration {
        case ..<0:
            return Color.red.opacity(0.3)
        case 0...2:
            return Color.orange.opacity(0.3)
        default:
            return Color.green.opacity(0.2)
        }
    }
    
    func saveFoodItems() {
        if let encoded = try? JSONEncoder().encode(foodItems) {
            UserDefaults.standard.set(encoded, forKey: "FoodItems")
        }
    }
    
    func loadFoodItems() {
        if let savedData = UserDefaults.standard.data(forKey: "FoodItems"),
           let decoded = try? JSONDecoder().decode([FoodItem].self, from: savedData) {
            foodItems = decoded
        }
    }
    
    func saveGroceryItems() {
        UserDefaults.standard.set(groceryItems, forKey: "GroceryItems")
    }
    
    func loadGroceryItems() {
        if let saved = UserDefaults.standard.stringArray(forKey: "GroceryItems") {
            groceryItems = saved
        }
    }
    
    func deleteGroceryItems(at offsets: IndexSet) {
        groceryItems.remove(atOffsets: offsets)
        saveGroceryItems()
    }
    
    func scheduleNotification(for item: FoodItem) {
        let content = UNMutableNotificationContent()
        content.title = "Expiration Reminder"
        content.body = "\(item.name) is expiring soon!"
        content.sound = UNNotificationSound.default

        let calendar = Calendar.current
        if let triggerDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: item.expirationDate) {
            let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

            let request = UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }
}

#Preview {
    ContentView()
}
