import Foundation

// MARK: - Runner profile

enum RunnerLevel: String, Codable, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    var id: String { rawValue }
}

enum ProfileGender: String, Codable, CaseIterable, Identifiable {
    case male = "male"
    case female = "female"
    case other = "other"
    case unspecified = "unspecified"

    var id: String { rawValue }
}

struct TesterProfile: Codable, Equatable {
    var firstName: String = ""
    var lastName: String = ""
    var nickname: String = ""
    var email: String = ""
    var level: RunnerLevel = .beginner
    var weeklyMileageKm: Double = 15
    var runningDaysPerWeek: Int = 3
    var heightCm: Double = 170
    var weightKg: Double = 70
    var target: String = "General Fitness"
    var injuryNote: String = ""
    var dateOfBirth: Date? = nil
    var weeklyExerciseHours: Double = 5
    var gender: ProfileGender = .unspecified
    var shoeSize: String = ""
    var legLengthCm: Double? = nil
    var shoeBrandModel: String = ""

    enum CodingKeys: String, CodingKey {
        case firstName
        case lastName
        case nickname
        case email
        case level
        case weeklyMileageKm
        case runningDaysPerWeek
        case heightCm
        case weightKg
        case target
        case injuryNote
        case dateOfBirth
        case weeklyExerciseHours
        case gender
        case shoeSize
        case legLengthCm
        case shoeBrandModel
    }

    init(
        firstName: String = "",
        lastName: String = "",
        nickname: String = "",
        email: String = "",
        level: RunnerLevel = .beginner,
        weeklyMileageKm: Double = 15,
        runningDaysPerWeek: Int = 3,
        heightCm: Double = 170,
        weightKg: Double = 70,
        target: String = "General Fitness",
        injuryNote: String = "",
        dateOfBirth: Date? = nil,
        weeklyExerciseHours: Double = 5,
        gender: ProfileGender = .unspecified,
        shoeSize: String = "",
        legLengthCm: Double? = nil,
        shoeBrandModel: String = ""
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.nickname = nickname
        self.email = email
        self.level = level
        self.weeklyMileageKm = weeklyMileageKm
        self.runningDaysPerWeek = runningDaysPerWeek
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.target = target
        self.injuryNote = injuryNote
        self.dateOfBirth = dateOfBirth
        self.weeklyExerciseHours = weeklyExerciseHours
        self.gender = gender
        self.shoeSize = shoeSize
        self.legLengthCm = legLengthCm
        self.shoeBrandModel = shoeBrandModel
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        firstName = try c.decodeIfPresent(String.self, forKey: .firstName) ?? ""
        lastName = try c.decodeIfPresent(String.self, forKey: .lastName) ?? ""
        nickname = try c.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
        level = try c.decodeIfPresent(RunnerLevel.self, forKey: .level) ?? .beginner
        weeklyMileageKm = try c.decodeIfPresent(Double.self, forKey: .weeklyMileageKm) ?? 15
        runningDaysPerWeek = try c.decodeIfPresent(Int.self, forKey: .runningDaysPerWeek) ?? 3
        heightCm = try c.decodeIfPresent(Double.self, forKey: .heightCm) ?? 170
        weightKg = try c.decodeIfPresent(Double.self, forKey: .weightKg) ?? 70
        target = try c.decodeIfPresent(String.self, forKey: .target) ?? "General Fitness"
        injuryNote = try c.decodeIfPresent(String.self, forKey: .injuryNote) ?? ""
        dateOfBirth = try c.decodeIfPresent(Date.self, forKey: .dateOfBirth)
        weeklyExerciseHours = try c.decodeIfPresent(Double.self, forKey: .weeklyExerciseHours) ?? 5
        gender = try c.decodeIfPresent(ProfileGender.self, forKey: .gender) ?? .unspecified
        shoeSize = try c.decodeIfPresent(String.self, forKey: .shoeSize) ?? ""
        legLengthCm = try c.decodeIfPresent(Double.self, forKey: .legLengthCm)
        shoeBrandModel = try c.decodeIfPresent(String.self, forKey: .shoeBrandModel) ?? ""
    }
}

struct ProfileSaveRequest: Encodable {
    let iosUserId: String
    let firstName: String?
    let lastName: String?
    let nickname: String?
    let level: String?
    let weeklyMileageKm: Double?
    let runningDaysPerWeek: Int?
    let heightCm: Double?
    let weightKg: Double?
    let target: String?
    let injuryNote: String?
    let gender: String?
    let shoeSize: String?
    let shoeBrandModel: String?
    let legLengthCm: Double?
    let dateOfBirth: String?
    let weeklyExerciseHours: Double?
    let email: String

    enum CodingKeys: String, CodingKey {
        case iosUserId = "ios_user_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case nickname
        case level
        case weeklyMileageKm = "weekly_mileage_km"
        case runningDaysPerWeek = "running_days_per_week"
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case target
        case injuryNote = "injury_note"
        case gender
        case shoeSize = "shoe_size"
        case shoeBrandModel = "shoe_brand_model"
        case legLengthCm = "leg_length_cm"
        case dateOfBirth = "date_of_birth"
        case weeklyExerciseHours = "weekly_exercise_hours"
        case email
    }
}

struct ProfileSaveResponse: Decodable {
    let saved: Bool
    let iosUserId: String
    enum CodingKeys: String, CodingKey {
        case saved
        case iosUserId = "ios_user_id"
    }
}

// MARK: - Auth

struct UserResponse: Codable, Equatable {
    let id: String
    let email: String
    let name: String?
    let googleSub: String?
    let emailVerified: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case googleSub = "google_sub"
        case emailVerified = "email_verified"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        googleSub = try container.decodeIfPresent(String.self, forKey: .googleSub)
        emailVerified = try container.decodeIfPresent(Bool.self, forKey: .emailVerified) ?? false
    }

    init(id: String, email: String, name: String?, googleSub: String?, emailVerified: Bool) {
        self.id = id
        self.email = email
        self.name = name
        self.googleSub = googleSub
        self.emailVerified = emailVerified
    }
}

struct AuthResponse: Codable, Equatable {
    let accessToken: String
    let user: UserResponse

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case user
    }
}

struct RegisterRequest: Encodable {
    let email: String
    let password: String
    let name: String?
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct PasswordResetRequest: Encodable {
    let email: String
}

struct PasswordResetRequestResponse: Decodable {
    let sent: Bool
    let message: String
}

struct GoogleAuthRequest: Encodable {
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}
