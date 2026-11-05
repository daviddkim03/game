import Foundation

public struct TutoringSession: Identifiable, Hashable, Sendable {
    public var id: Int
    /// "YYYY-MM-DD", or "" until picked.
    public var date: String
    /// "HH:MM" (24h), or "".
    public var startTime: String
    public var hrs: Double

    public init(id: Int, date: String, startTime: String, hrs: Double) {
        self.id = id
        self.date = date
        self.startTime = startTime
        self.hrs = hrs
    }
}

public struct Student: Identifiable, Hashable, Sendable {
    public var id: Int
    public var name: String
    public var subject: String
    public var sessions: [TutoringSession]

    public init(id: Int, name: String, subject: String, sessions: [TutoringSession] = []) {
        self.id = id
        self.name = name
        self.subject = subject
        self.sessions = sessions
    }

    public var hours: Double {
        sessions.reduce(0) { $0 + $1.hrs }
    }
}

public struct PaymentReport: CloudValue {
    public var name: String
    /// Report period, "YYYY-MM-DD".
    public var start: String
    public var end: String
    public var rate: Double
    public var every: String
    public var students: [Student]
    public var nextId: Int

    public static let empty = PaymentReport(
        name: "", start: "", end: "", rate: 0, every: "", students: [], nextId: 1)

    public init(
        name: String, start: String, end: String, rate: Double, every: String, students: [Student],
        nextId: Int
    ) {
        self.name = name
        self.start = start
        self.end = end
        self.rate = rate
        self.every = every
        self.students = students
        self.nextId = nextId
    }

    public init?(json: JSONValue) {
        guard case .object = json else { return nil }
        let students: [Student] = (json["students"]?.arrayValue ?? []).compactMap { item in
            guard let id = item["id"]?.intValue else { return nil }
            let sessions: [TutoringSession] = (item["sessions"]?.arrayValue ?? []).compactMap { raw in
                guard let id = raw["id"]?.intValue else { return nil }
                return TutoringSession(
                    id: id,
                    date: raw["date"]?.stringValue ?? "",
                    startTime: raw["startTime"]?.stringValue ?? "",
                    hrs: raw["hrs"]?.doubleValue ?? 0)
            }
            return Student(
                id: id,
                name: item["name"]?.stringValue ?? "",
                subject: item["subject"]?.stringValue ?? "",
                sessions: sessions)
        }
        self.init(
            name: json["name"]?.stringValue ?? "",
            start: json["start"]?.stringValue ?? "",
            end: json["end"]?.stringValue ?? "",
            rate: json["rate"]?.doubleValue ?? 0,
            every: json["every"]?.stringValue ?? "",
            students: students,
            nextId: json["nextId"]?.intValue ?? 1)
    }

    public func toJSON() -> JSONValue {
        [
            "name": .string(name),
            "start": .string(start),
            "end": .string(end),
            "rate": .number(rate),
            "every": .string(every),
            "students": .array(
                students.map { student in
                    [
                        "id": .number(Double(student.id)),
                        "name": .string(student.name),
                        "subject": .string(student.subject),
                        "sessions": .array(
                            student.sessions.map { session in
                                [
                                    "id": .number(Double(session.id)),
                                    "date": .string(session.date),
                                    "startTime": .string(session.startTime),
                                    "hrs": .number(session.hrs),
                                ]
                            }),
                    ]
                }),
            "nextId": .number(Double(nextId)),
        ]
    }

    public var hours: Double {
        students.reduce(0) { $0 + $1.hours }
    }

    public var total: Double {
        hours * rate
    }

    public func total(for student: Student) -> Double {
        student.hours * rate
    }

    public mutating func addStudent(name: String, subject: String) {
        students.append(Student(id: nextId, name: name, subject: subject))
        nextId += 1
    }

    public mutating func save(_ session: TutoringSession, studentId: Int) {
        guard let index = students.firstIndex(where: { $0.id == studentId }) else { return }
        if let existing = students[index].sessions.firstIndex(where: { $0.id == session.id }) {
            students[index].sessions[existing] = session
            return
        }
        var added = session
        added.id = nextId
        nextId += 1
        students[index].sessions.append(added)
    }

    public mutating func deleteSession(_ id: Int, studentId: Int) {
        guard let index = students.firstIndex(where: { $0.id == studentId }) else { return }
        students[index].sessions.removeAll { $0.id == id }
    }

    /// The student a schedule block is for, when its label names one.
    public func student(matching label: String) -> Student? {
        let lowered = label.lowercased()
        return students.first { student in
            let name = student.name.lowercased()
            return !name.isEmpty && lowered.contains(name)
        }
    }

    /// True for a block that is a tutoring session: it says so, or names a student.
    public func isTutoring(_ label: String) -> Bool {
        label.lowercased().contains("tutor") || student(matching: label) != nil
    }
}

/// "5/2" for "2026-05-02", as on the printed report.
public func shortDate(_ value: String) -> String {
    let parts = value.split(separator: "-").compactMap { Int($0) }
    return parts.count == 3 ? "\(parts[1])/\(parts[2])" : value
}

/// "10:00 AM" for "10:00".
public func clockTime(_ value: String) -> String {
    let parts = value.split(separator: ":").compactMap { Int($0) }
    guard parts.count == 2 else { return value }
    return clockLabel(parts[0] * 60 + parts[1])
}

/// "10:00" for 600 minutes past midnight.
public func hhmm(_ minutes: Int) -> String {
    String(format: "%02d:%02d", minutes / 60, minutes % 60)
}
