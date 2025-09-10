-- Students table
CREATE TABLE Students (
    StudentID INT PRIMARY KEY,
    FirstName VARCHAR(50) NOT NULL,
    LastName VARCHAR(50) NOT NULL,
    Age INT,
    EnrollmentDate DATE
);

-- Courses table
CREATE TABLE Courses (
    CourseID INT PRIMARY KEY ,
    CourseName VARCHAR(100) NOT NULL
);

-- Enrollments table (joins Students and Courses)
CREATE TABLE Enrollments (
    EnrollmentID INT PRIMARY KEY ,
    StudentID INT,
    CourseID INT,
    EnrollDate DATE,
    FOREIGN KEY (StudentID) REFERENCES Students(StudentID),
    FOREIGN KEY (CourseID) REFERENCES Courses(CourseID)
);
