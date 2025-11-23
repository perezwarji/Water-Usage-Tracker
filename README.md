# 💧 Water Usage Tracker

A comprehensive Stacks smart contract for tracking and managing water consumption with conservation incentives.

## 🌟 Features

- **User Registration** 📝 - Register with daily water usage limits
- **Daily Tracking** 📊 - Record and monitor daily water consumption
- **Conservation Scoring** 🏆 - Earn points for water conservation efforts
- **Monthly Analytics** 📈 - View detailed monthly usage statistics
- **Leaderboard** 🥇 - See top water conservers in the community
- **Reward System** 🎁 - Get conservation rewards for staying under limits
- **Usage History** 📋 - Track historical water usage patterns

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet or testing environment

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd Water-Usage-Tracker
```

2. Check contract validity:
```bash
clarinet check
```

3. Run tests:
```bash
npm install
npm test
```

## 📖 Contract Functions

### 📝 User Management

#### `register-user`
Register a new user with a daily water usage limit.
```clarity
(contract-call? .Water-Usage-Tracker register-user u100)
```

#### `update-daily-limit`
Update your daily water usage limit.
```clarity
(contract-call? .Water-Usage-Tracker update-daily-limit u150)
```

#### `deactivate-account` / `reactivate-account`
Temporarily deactivate or reactivate your tracking account.

### 💧 Usage Tracking

#### `record-usage`
Record daily water usage in liters.
```clarity
(contract-call? .Water-Usage-Tracker record-usage u50)
```

### 📊 Analytics & Reports

#### `get-user-info`
Get comprehensive user information including total usage and conservation score.
```clarity
(contract-call? .Water-Usage-Tracker get-user-info 'SP1234...)
```

#### `get-daily-usage`
Check water usage for a specific date.
```clarity
(contract-call? .Water-Usage-Tracker get-daily-usage 'SP1234... u18900)
```

#### `get-monthly-stats`
View monthly usage statistics.
```clarity
(contract-call? .Water-Usage-Tracker get-monthly-stats 'SP1234... u12 u2024)
```

#### `get-user-usage-history`
Get usage history between two dates (max 30 days).
```clarity
(contract-call? .Water-Usage-Tracker get-user-usage-history 'SP1234... u18900 u18930)
```

### 🏆 Leaderboard & Rewards

#### `get-top-conservers`
View the top water conservation performers.
```clarity
(contract-call? .Water-Usage-Tracker get-top-conservers u10)
```

#### `get-conservation-rewards`
Check your conservation reward balance.
```clarity
(contract-call? .Water-Usage-Tracker get-conservation-rewards 'SP1234...)
```

#### `calculate-water-savings`
Calculate total water saved compared to daily limits.
```clarity
(contract-call? .Water-Usage-Tracker calculate-water-savings 'SP1234...)
```

### 📈 Global Statistics

#### `get-total-users`
Get the total number of registered users.

#### `get-total-water-used`
Get the total amount of water tracked across all users.

## 💡 How It Works

1. **Registration** 📋: Users register with a daily water usage limit
2. **Daily Tracking** ⏰: Record water usage throughout the day
3. **Conservation Scoring** 🎯: System calculates conservation score based on usage vs. limits
4. **Rewards** 🎁: Users earn rewards for maintaining good conservation scores
5. **Analytics** 📊: View personal and community-wide usage statistics

## 🎯 Conservation Score Calculation

Conservation score = (Max Possible Usage - Actual Usage) × 100

Higher scores indicate better water conservation habits!

## 🔒 Error Codes

- `u100`: Not authorized
- `u101`: User not found
- `u102`: Invalid amount
- `u103`: Daily limit exceeded
- `u104`: User already registered
- `u105`: Invalid date range



## 📄 License

This project is open source and available under the MIT License.

---

💧 **Start tracking your water usage today and contribute to a more sustainable future!** 🌍
