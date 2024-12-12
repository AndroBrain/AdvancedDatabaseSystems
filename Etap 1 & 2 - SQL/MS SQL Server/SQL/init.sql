CREATE TABLE Manager (
    ID INT PRIMARY KEY IDENTITY(1,1),
    Name VARCHAR(55) NOT NULL,
    Surname VARCHAR(55) NOT NULL,
    Email VARCHAR(254) NOT NULL,
    PhoneNumber VARCHAR(15) NOT NULL
);

CREATE TABLE Doctor (
    ID INT PRIMARY KEY IDENTITY(1,1),
    Name VARCHAR(55) NOT NULL,
    Surname VARCHAR(55) NOT NULL,
    Email VARCHAR(254) NOT NULL,
    PhoneNumber VARCHAR(15) NOT NULL,
    Pesel VARCHAR(11) NOT NULL,
    ManagerID INT /* SQLines: Changed to match the PK data type */,
    CONSTRAINT fk_manager FOREIGN KEY (ManagerID) REFERENCES Manager(ID)
);

CREATE TABLE Specialization (
    ID INT PRIMARY KEY IDENTITY(1,1),
    Name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE DoctorSpecialization (
    ID INT PRIMARY KEY IDENTITY(1,1),
    DoctorID INT /* SQLines: Changed to match the PK data type */,
    SpecializationID INT /* SQLines: Changed to match the PK data type */,
    CONSTRAINT fk_doctor FOREIGN KEY (DoctorID) REFERENCES Doctor(ID),
    CONSTRAINT fk_specialization FOREIGN KEY (SpecializationID) REFERENCES Specialization(ID)
);

CREATE TABLE Patient (
    ID INT PRIMARY KEY IDENTITY(1,1),
    Name VARCHAR(55) NOT NULL,
    Surname VARCHAR(55) NOT NULL,
    Email VARCHAR(254) NOT NULL,
    PhoneNumber VARCHAR(15) NOT NULL
);

CREATE TABLE Appointment (
    ID INT PRIMARY KEY IDENTITY(1,1),
    Date DATE NOT NULL,
    Comment VARCHAR(520),
    DoctorID INT /* SQLines: Changed to match the PK data type */,
    PatientID INT /* SQLines: Changed to match the PK data type */,
    CONSTRAINT fk_a_doctor FOREIGN KEY (DoctorID) REFERENCES Doctor(ID),
    CONSTRAINT fk_a_patient FOREIGN KEY (PatientID) REFERENCES Patient(ID)
);

CREATE TABLE Rating (
    ID INT PRIMARY KEY IDENTITY(1,1),
    Satisfaction INTEGER,
    AppointmentID INT /* SQLines: Changed to match the PK data type */,
    CONSTRAINT fk_appointment FOREIGN KEY (AppointmentID) REFERENCES Appointment(ID)
);

CREATE TABLE Prescription (
    ID INT PRIMARY KEY IDENTITY(1,1),
    Code VARCHAR(50) NOT NULL,
    AppointmentID INT /* SQLines: Changed to match the PK data type */,
    CONSTRAINT fk_p_appointment FOREIGN KEY (AppointmentID) REFERENCES Appointment(ID)
);

CREATE TABLE Medicine (
    ID INT PRIMARY KEY IDENTITY(1,1),
    Name VARCHAR(250) NOT NULL
);

CREATE TABLE MedicinePrescription (
    ID INT PRIMARY KEY IDENTITY(1,1),
    PrescriptionID INT /* SQLines: Changed to match the PK data type */,
    MedicineID INT /* SQLines: Changed to match the PK data type */,
    CONSTRAINT fk_mp_prescription FOREIGN KEY (PrescriptionID) REFERENCES Prescription(ID),
    CONSTRAINT fk_mp_medicine FOREIGN KEY (MedicineID) REFERENCES Medicine(ID)
);

CREATE FUNCTION dbo.get_appointment_count(@patient_id INT)
RETURNS INT
AS
BEGIN
    DECLARE @appointment_count INT;

    SELECT @appointment_count = COUNT(*)
    FROM Appointment a
    WHERE a.PatientID = @patient_id;

    RETURN @appointment_count;
END;

CREATE FUNCTION dbo.get_visits(@patient_id INT)
RETURNS TABLE
AS
RETURN
(
    SELECT
        a.date,
        d.name AS doctor_name,
        d.surname AS doctor_surname,
        a.comment,
        r.satisfaction,
        p.code AS prescription_code,
        STRING_AGG(m.name, ', ') WITHIN GROUP (ORDER BY m.name) AS medicines
    FROM appointment a
    LEFT JOIN rating r ON a.id = r.appointmentid
    LEFT JOIN prescription p ON a.id = p.appointmentid
    LEFT JOIN medicineprescription mp ON p.id = mp.prescriptionid
    LEFT JOIN medicine m ON mp.medicineid = m.id
    LEFT JOIN doctor d ON d.id = a.doctorid
    WHERE a.patientid = @patient_id
    GROUP BY a.id, d.name, d.surname, a.date, a.comment, r.satisfaction, p.code
);

CREATE FUNCTION dbo.get_available_doctors(
    @specializations NVARCHAR(MAX),  -- Pass as comma-separated string
    @min_specializations INT,
    @check_date DATE
)
RETURNS TABLE
AS
RETURN
(
    SELECT DISTINCT d.name, d.surname
    FROM doctor d
    JOIN (
        SELECT ds.doctorID
        FROM doctorspecialization ds
        JOIN specialization s ON ds.specializationID = s.ID
        WHERE CHARINDEX(s.name, @specializations) > 0
        GROUP BY ds.doctorID
        HAVING COUNT(DISTINCT s.name) >= @min_specializations
    ) AS specializedDoctors ON d.id = specializedDoctors.doctorID
    JOIN (
        SELECT a.doctorID
        FROM appointment a
        WHERE a.date != @check_date
    ) AS availableDoctors ON d.id = availableDoctors.doctorID
);

CREATE PROCEDURE dbo.add_specializations(
    @doctor_id INT,
    @specializations NVARCHAR(MAX) -- Pass as comma-separated list
)
AS
BEGIN
    DECLARE @spec_name NVARCHAR(100);
    DECLARE @spec_id INT;
    DECLARE @xml XML = CAST('<i>' + REPLACE(@specializations, ',', '</i><i>') + '</i>' AS XML);

    DECLARE specialization_cursor CURSOR FOR
    SELECT T.c.value('.', 'NVARCHAR(100)') AS specialization
    FROM @xml.nodes('/i') AS T(c);

    OPEN specialization_cursor;

    FETCH NEXT FROM specialization_cursor INTO @spec_name;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @spec_id = id FROM specialization WHERE name = @spec_name;

        IF @spec_id IS NOT NULL
        BEGIN
            INSERT INTO doctorspecialization (DoctorID, SpecializationID)
            VALUES (@doctor_id, @spec_id);
        END;

        FETCH NEXT FROM specialization_cursor INTO @spec_name;
    END;

    CLOSE specialization_cursor;
    DEALLOCATE specialization_cursor;
END;

CREATE PROCEDURE dbo.add_medicine(
    @medicine_name NVARCHAR(250),
    @medicine_id INT OUTPUT
)
AS
BEGIN
    SET @medicine_id = (SELECT ID FROM Medicine WHERE Name = @medicine_name);

    IF @medicine_id IS NULL
    BEGIN
        INSERT INTO medicine (name) VALUES (@medicine_name);
        SET @medicine_id = SCOPE_IDENTITY();
    END;
END;


DROP PROCEDURE dbo.create_prescription

CREATE PROCEDURE dbo.create_prescription(
    @appointment_id INT,
    @medicine_names NVARCHAR(MAX) -- Pass as comma-separated string
)
AS
BEGIN
    DECLARE @prescription_id INT;
    DECLARE @medicine_id INT;
    DECLARE @prescription_code NVARCHAR(50) = LOWER(NEWID());
    DECLARE @medicine_name NVARCHAR(250);
    DECLARE @xml XML = CAST('<i>' + REPLACE(@medicine_names, ',', '</i><i>') + '</i>' AS XML);

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO prescription (Code, AppointmentID)
        VALUES (@prescription_code, @appointment_id);

        SET @prescription_id = SCOPE_IDENTITY();

        DECLARE medicine_cursor CURSOR FOR
        SELECT T.c.value('.', 'NVARCHAR(250)') AS medicine_name
        FROM @xml.nodes('/i') AS T(c);

        OPEN medicine_cursor;
        FETCH NEXT FROM medicine_cursor INTO @medicine_name;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.add_medicine @medicine_name, @medicine_id OUTPUT;
            INSERT INTO MedicinePrescription (PrescriptionID, MedicineID)
            VALUES (@prescription_id, @medicine_id);
            FETCH NEXT FROM medicine_cursor INTO @medicine_name;
        END;

        CLOSE medicine_cursor;
        DEALLOCATE medicine_cursor;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

CREATE PROCEDURE dbo.cancel_appointment(
    @appointment_id INT
)
AS
BEGIN
    DECLARE @appointment_date DATE;

    SELECT @appointment_date = date
    FROM Appointment
    WHERE ID = @appointment_id;

    IF @appointment_date > CAST(GETDATE() AS DATE)
    BEGIN
        DELETE FROM Appointment WHERE ID = @appointment_id;
    END
    ELSE
    BEGIN
        THROW 50000, 'Cannot cancel appointments from the past', 1;
    END;
END;

CREATE TRIGGER before_appointment_delete
ON Appointment
AFTER DELETE
AS
BEGIN
    DELETE FROM Rating
    WHERE AppointmentID IN (SELECT ID FROM deleted);

    DELETE FROM MedicinePrescription
    WHERE PrescriptionID IN (
        SELECT ID
        FROM Prescription
        WHERE AppointmentID IN (SELECT ID FROM deleted)
    );

    DELETE FROM Prescription
    WHERE AppointmentID IN (SELECT ID FROM deleted);
END;

CREATE TRIGGER before_appointment_insert
ON Appointment
INSTEAD OF INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted
        WHERE date < CAST(GETDATE() AS DATE)
    )
    BEGIN
        THROW 50000, 'Appointments can only be added in the future', 1;
    END
    ELSE
    BEGIN
        INSERT INTO Appointment (ID, date, PatientID, DoctorID, comment)
        SELECT ID, date, PatientID, DoctorID, comment
        FROM inserted;
    END;
END;



INSERT INTO manager (name, surname, email, phonenumber) VALUES
('John', 'Doe', 'john.doe@hospital.com', '123456789'),
('Emily', 'Smith', 'emily.smith@hospital.com', '987654321'),
('Adrian', 'Gone', 'adrian.gone@hospital.com', '987654321'),
('Managus', 'Mag', 'managus.mag@hospital.com', '987654321');

INSERT INTO specialization (name) VALUES
('Cardiology'),
('Dermatology'),
('Pediatrics'),
('Skeletonology');

INSERT INTO doctor (name, surname, email, phonenumber, pesel, managerid) VALUES
('Alice', 'Brown', 'alice.brown@hospital.com', '123123123', '12345678901', 1),
('Bob', 'Green', 'bob.green@hospital.com', '321321321', '98765432109', 2),
('Charlie', 'White', 'charlie.white@hospital.com', '456456456', '45678901234', 1),
('John', 'Johnson', 'john.johnson@hospital.com', '12315515', '35678901234', 1);

INSERT INTO doctorspecialization (doctorid, specializationid) VALUES
(1, 1),
(2, 2),
(3, 3),
(1, 2),
(2, 1),
(2, 3);

INSERT INTO patient (name, surname, email, phonenumber) VALUES
('David', 'Johnson', 'david.johnson@gmail.com', '111222333'),
('Eva', 'Taylor', 'eva.taylor@gmail.com', '444555666'),
('Frank', 'Williams', 'frank.williams@gmail.com', '777888999'),
('Adrian', 'Lov', 'adrian.lov@gmail.com', '889888998');

INSERT INTO appointment (date, comment, doctorid, patientid) VALUES
('2024-10-15', 'Regular check-up', 1, 1),
('2024-10-18', 'Skin rash', 2, 2),
('2024-10-20', 'Child consultation', 3, 3);

INSERT INTO medicine (name) VALUES
('Aspirin'),
('Ibuprofen'),
('Paracetamol'),
('Apap'),
('Penicylyna'),
('AntyBol');

INSERT INTO prescription (code, appointmentid) VALUES
('RX12345', 1),
('RX67890', 2),
('RX77890', 3);

INSERT INTO medicineprescription (prescriptionid, medicineid) VALUES
(1, 1),
(2, 2),
(3, 3);

INSERT INTO rating (satisfaction, appointmentid) VALUES
(5, 1),
(4, 2);


CREATE LOGIN Manager WITH PASSWORD = 'StrongPassword1!';
CREATE LOGIN Doctor WITH PASSWORD = 'StrongPassword2!';
CREATE LOGIN Patient WITH PASSWORD = 'StrongPassword3!';

CREATE USER Manager FOR LOGIN Manager;
CREATE USER Doctor FOR LOGIN Doctor;
CREATE USER Patient FOR LOGIN Patient;

GRANT EXECUTE ON OBJECT::dbo.add_specializations TO Manager;

GRANT EXECUTE ON OBJECT::dbo.add_medicine TO Doctor;
GRANT EXECUTE ON OBJECT::dbo.create_prescription TO Doctor;

GRANT SELECT ON OBJECT::dbo.get_visits TO Patient;
GRANT SELECT ON OBJECT::dbo.get_available_doctors TO Patient;
GRANT EXECUTE ON OBJECT::dbo.cancel_appointment TO Patient;

CREATE NONCLUSTERED INDEX IX_Appointment_Date ON appointment (date);
CREATE NONCLUSTERED INDEX IX_Appointment_DoctorID ON appointment (doctorid);
CREATE NONCLUSTERED INDEX IX_Appointment_PatientID ON appointment (patientid);
CREATE NONCLUSTERED INDEX IX_DoctorSpecialization_DoctorID ON doctorspecialization (doctorid);
CREATE NONCLUSTERED INDEX IX_DoctorSpecialization_SpecializationID ON doctorspecialization (specializationid);
CREATE NONCLUSTERED INDEX IX_MedicinePrescription_PrescriptionID ON medicineprescription (prescriptionid);
CREATE NONCLUSTERED INDEX IX_MedicinePrescription_MedicineID ON medicineprescription (medicineid);
CREATE NONCLUSTERED INDEX IX_Prescription_AppointmentID ON prescription (appointmentid);
CREATE NONCLUSTERED INDEX IX_Rating_AppointmentID ON rating (appointmentid);