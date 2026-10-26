# KindPlate — Complete AI-Powered Food Rescue & Care Platform 🌿🤝

> **“Good Food. Less Waste. More Care.”**  
> *Real Food, Real People, Real Impact 💚*

Built with **Flutter & Dart** for cross-platform delivery across **Web, Android, iOS, and Desktop**, backed by complete Firebase rules, data models, cloud functions, and an interactive offline demo engine.

---

## 🎨 Visual Identity & First 3 Onboarding Screens

The app faithfully implements the user-provided KindPlate visual identity and initial 3 screens:

1. **Screen 1 (Poster Splash)**:
   - KindPlate leaf lettermark, fork, protective hand, and green heart emblem.
   - Wordmark **KindPlate** in deep forest green with a sprouting leaf dotting the 'i'.
   - Handwritten script accents: *"Real Food, Real People, Real Impact 💚"*.
   - Authentic fresh produce box with green heart sticker.

2. **Screen 2 (Mobile Welcome)**:
   - 9:41 status bar with battery and connectivity indicator.
   - Green eco-city skyline illustration with green buildings and hills.
   - Green KindPlate delivery van carrying wholesome meals.
   - Forest green rounded **"Get Started"** button and **"Already have an account? Log In"** link.

3. **Screen 3 (Small Actions, Big Impact)**:
   - Headline: *"Small Actions. Big Impact."*
   - Subtitle: *"Surplus food from restaurants, home bakers and more — reaching people who need it."*
   - Illustration: Two hands reaching out, passing a fresh produce container with a heart sticker.
   - 3 Feature badges:
     - 🍃 **Reduce Food Waste**
     - 👥 **Support Communities**
     - 🌍 **Build a Greener Planet**
   - *"Powered by KindPlate"* with forest green rounded **"Next"** button.

---

## 🤝 The Signature Order Animation: “The Kindness Handshake”

When any rescue meal order or free care request is confirmed, KindPlate transitions into a full-screen animated celebration:

1. **Meal Preparation**: Shows the chef/donor carefully packing the surplus meal in a glowing leaf container.
2. **The Leafy Path**: An animated meal package travels along a curved winding green trail with gentle floating leaves and warm sparkles.
3. **The Emotional Climax (Handover & Handshake)**:
   - Donor/courier character meets the customer character.
   - Food package is handed over with a happy, grateful expression.
   - Characters extend hands in an **animated handshake 🤝** with a glowing pulsing green heart between them.
   - Text banner: *"Food shared. Hearts connected."*
4. **Celebration & Confirmation**:
   - Confetti celebration burst.
   - Real Order Number and 4-digit **Handover Verification Code**.
   - Green Tokens awarded (+25 Tokens for rescues, +15 for care requests).
   - Direct button to **Live Order Tracking**.

---

## 👥 6 Supported User Roles

Switch between all 6 personas in 1 tap using the top **Role Switcher Bar**:

1. **🛒 Surplus Food Buyer (`Alex Rivera`)**:
   - Discover discounted bakery baskets and meals at 50–70% off.
   - Search by distance, category, allergies, and collection deadline.
   - Cart & Checkout with self-pickup or volunteer delivery options.
   - Earn Green Tokens and track live orders on the simulated GPS map.

2. **💚 Care Recipient / Free Food (`Maria Chen`)**:
   - Dignity-first, private portal. No public proof of poverty required.
   - 100% Free donations ($0.00 total) from community farms and kitchens.
   - Portion selector, allergy notes, and delivery or pickup choice.

3. **🥖 Restaurant & Home Baker (`Elena Rostova` — Green Crust Bakery)**:
   - Business dashboard with saved waste metrics (kg), orders, and revenue recovered.
   - Add/edit listing form with portion limits, original vs discount price, or 100% free donation toggle.
   - Manage incoming orders and verify handover codes.
   - **AI Surplus Insights** predicting evening demand and optimal discounts.

4. **🚴 Volunteer & Delivery Partner (`David Kim`)**:
   - Online/Offline availability toggle.
   - Active delivery task list (pickup from donor -> deliver to customer/shelter).
   - Route distance & ETA calculation.
   - QR/Code verification to confirm pickup and customer handover.
   - Earns +35 to +45 Green Tokens per completed delivery.

5. **🤝 NGO & Community Coordinator (`Amara Patel` — CarePlate Hub)**:
   - Manage bulk donations (e.g. 50 loaves of artisanal bread from central kitchens).
   - Allocate surplus to registered shelters and local kitchens.
   - Authorize volunteer drivers and monitor fulfillment rates.

6. **⚙️ Platform Administrator (`Sarah Jenkins`)**:
   - Review partner food hygiene licenses and cottage food permits.
   - Moderate active listings and price thresholds.
   - Real-time immutable audit logs and duplicate-order prevention.

---

## 🤖 KindPlate AI Suite

- **AI Assistant**: Conversational assistant helping find vegan bakery surplus, locate free meal donations, and explain token rules.
- **AI Surplus Prediction**: Predictive model for food businesses analyzing day-of-week trends and optimal listing windows.
- **AI Rescue Radar**: Highlights listings expiring within 1–2 hours.
- **GreenPlate Impact Score**: Real-time counter of meals rescued, free meals given, kg CO₂ emissions prevented, and tree equivalents.

---

## 🪙 KindPlate Green Rewards

- **Progression Badges**:
  - `Seed` (0–99 Tokens)
  - `Sprout` (100–299 Tokens)
  - `Green Guardian` (300–699 Tokens)
  - `Planet Hero` (700+ Tokens)
- **Redemption Catalog**:
  - $5 Off Surplus Food Order (75 Tokens)
  - Carbon-Neutral Delivery Pass (50 Tokens)
  - Plant 1 Tree via Eden Reforestation (100 Tokens)
  - Organic Cotton Tote Bag (150 Tokens)
- **Community Challenges**:
  - *Weekend Surplus Sprint* (Target: 500 meals)
  - *Zero Bakery Waste Drive* (Target: 200 bakery items)

---

## 🚀 Running the Project

### Prerequisites
- Flutter SDK (v3.44.0 or newer)
- Dart SDK (v3.12.0 or newer)
- Google Chrome or Microsoft Edge

### Run Locally on Web
```bash
flutter run -d chrome
```

### Run Locally on Windows Desktop
```bash
flutter run -d windows
```

### Run Automated Tests
```bash
flutter test
```

### Build Production Web App
```bash
flutter build web --release --base-href /
```

---

## 📁 Repository Structure

```
kindplate/
├── assets/
│   ├── branding/              # Reference images (Poster, Welcome Van, Small Actions)
│   ├── food/                  # Photography assets
│   └── illustrations/         # Vector illustrations
├── lib/
│   ├── core/
│   │   └── theme/             # AppColors, AppTypography, AppTheme
│   ├── data/
│   │   └── seed_data.dart     # Seed listings, sellers, users, challenges
│   ├── models/                # User, Seller, Listing, Order, Delivery, Reward, AI models
│   ├── state/
│   │   └── app_state.dart     # ChangeNotifier state store
│   ├── widgets/
│   │   ├── common/            # KindPlateLogo, RoleSwitchBar
│   │   └── animations/        # SignatureHandshakeDialog (The Kindness Handshake 🤝🌿)
│   ├── screens/
│   │   ├── onboarding/        # SplashPosterScreen, WelcomeCityScreen, ImpactFeaturesScreen, RoleSelectionScreen
│   │   ├── buyer/             # BuyerHomeScreen, FoodDetailSheet, CartCheckoutScreen, LiveOrderTrackingScreen
│   │   ├── recipient/         # FreeDonationPortalScreen
│   │   ├── seller/            # SellerDashboardScreen, AddListingScreen
│   │   ├── volunteer/         # VolunteerDashboardScreen
│   │   ├── ngo/               # NGOCoordinatorScreen
│   │   ├── admin/             # AdminPortalScreen
│   │   ├── rewards/           # GreenRewardsScreen
│   │   ├── ai/                # KindPlateAIScreen
│   │   └── navigation/        # MainNavigationShell (with mobile preview frame toggle)
│   └── main.dart              # Main entry point
├── test/
│   └── widget_test.dart       # Automated smoke & branding tests
├── functions/
│   └── src/index.ts           # Firebase Cloud Functions (order processing, token ledger)
├── firebase.json              # Firebase Hosting, Functions, Firestore config
├── firestore.rules            # Firestore security rules
├── firestore.indexes.json     # Firestore compound query indexes
├── storage.rules              # Firebase Storage rules
├── pubspec.yaml               # Flutter & Dart dependencies
└── README.md
```
