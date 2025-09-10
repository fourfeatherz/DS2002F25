# SQL DDL and Joins Overview

This document summarizes what we covered on SQL Data Definition Language (DDL) and SQL Joins, with examples of syntax and use cases.

---

## Data Definition Language (DDL)

DDL defines and modifies database structures. Common DDL commands include:

- **CREATE** – Create a new database object (table, index, etc.)
- **ALTER** – Modify an existing database object
- **DROP** – Permanently remove an object
- **TRUNCATE** – Remove all rows from a table but keep its structure

### Example: CREATE TABLE

```sql
CREATE TABLE Students (
    StudentID INT PRIMARY KEY,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    Age INT,
    EnrollmentDate DATE
);
```

```sql
CREATE TABLE Courses (
    CourseID INT PRIMARY KEY,
    CourseName VARCHAR(100) NOT NULL
);
```

### Example: DROP TABLE

```sql
DROP TABLE Students;
```

Caution: This permanently deletes the table.

### Example: TRUNCATE TABLE

```sql
TRUNCATE TABLE Students;
```

This deletes all rows quickly while keeping the table structure intact.

---

## Basic SQL (DML Refresh)

- **SELECT** – Retrieve data
- **INSERT** – Add data
- **UPDATE** – Modify data
- **DELETE** – Remove data

### SELECT Basics

```sql
SELECT FirstName, LastName FROM Students;
```

```sql
SELECT * FROM Students; -- returns all columns
```

### Filtering with WHERE

```sql
SELECT FirstName, Age 
FROM Students
WHERE Age > 20;
```

### Sorting with ORDER BY

```sql
SELECT FirstName, Age 
FROM Students
ORDER BY Age DESC;
```

---

## SQL Joins

Joins combine data across multiple tables based on related columns.

### INNER JOIN

```sql
SELECT s.StudentID, s.FirstName, s.LastName, c.CourseName
FROM Students s
INNER JOIN Enrollments e ON s.StudentID = e.StudentID
INNER JOIN Courses c ON e.CourseID = c.CourseID;
```

### LEFT OUTER JOIN

```sql
SELECT s.StudentID, s.FirstName, s.LastName, c.CourseName
FROM Students s
LEFT JOIN Enrollments e ON s.StudentID = e.StudentID
LEFT JOIN Courses c ON e.CourseID = c.CourseID;
```

### RIGHT OUTER JOIN

```sql
SELECT c.CourseID, c.CourseName, s.FirstName, s.LastName
FROM Courses c
RIGHT JOIN Enrollments e ON c.CourseID = e.CourseID
RIGHT JOIN Students s ON e.StudentID = s.StudentID;
```

### SELF JOIN

```sql
SELECT 
    A.FirstName AS Student1, A.LastName AS LastName1,
    B.FirstName AS Student2, B.LastName AS LastName2,
    A.EnrollmentDate
FROM Students A
INNER JOIN Students B  
    ON A.EnrollmentDate = B.EnrollmentDate
   AND A.StudentID < B.StudentID;
```

---

## Aggregations and Grouping

### Aggregate Functions

- `COUNT()`
- `SUM()`
- `AVG()`
- `MIN()`
- `MAX()`

```sql
SELECT COUNT(*) AS TotalStudents FROM Students;
```

### GROUP BY

```sql
SELECT c.CourseName, COUNT(*) AS StudentCount
FROM Enrollments e
JOIN Courses c ON e.CourseID = c.CourseID
GROUP BY c.CourseName;
```

---



---

## Quick Reference Cheat Sheet

| Command | Purpose | Example |
|---------|---------|---------|
| `CREATE TABLE` | Define a new table | `CREATE TABLE Students (...);` |
| `ALTER TABLE` | Modify an existing table | `ALTER TABLE Students ADD Email VARCHAR(100);` |
| `DROP TABLE` | Delete a table permanently | `DROP TABLE Students;` |
| `TRUNCATE TABLE` | Remove all rows but keep structure | `TRUNCATE TABLE Students;` |
| `SELECT` | Retrieve data | `SELECT * FROM Students;` |
| `INSERT` | Add new rows | `INSERT INTO Students VALUES (...);` |
| `UPDATE` | Modify existing rows | `UPDATE Students SET Age=21 WHERE StudentID=1;` |
| `DELETE` | Remove rows | `DELETE FROM Students WHERE Age < 18;` |
| `INNER JOIN` | Rows with matches in both tables | `... INNER JOIN Courses ...` |
| `LEFT JOIN` | All left rows + matches | `... LEFT JOIN Courses ...` |
| `RIGHT JOIN` | All right rows + matches | `... RIGHT JOIN Students ...` |
| `SELF JOIN` | Table joined with itself | `... FROM Students A JOIN Students B ...` |
| `GROUP BY` | Group rows for aggregates | `GROUP BY CourseName;` |
| Aggregates | Summaries of data | `COUNT(), SUM(), AVG(), MIN(), MAX()` |

