CREATE TABLE IF NOT EXISTS Manager (
    ID SERIAL PRIMARY KEY,
    Name VARCHAR(55) NOT NULL,
    Surname VARCHAR(55) NOT NULL,
    Email VARCHAR(254) NOT NULL,
    PhoneNumber VARCHAR(15) NOT NULL
);

CREATE TABLE IF NOT EXISTS Doctor (
    ID SERIAL PRIMARY KEY,
    Name VARCHAR(55) NOT NULL,
    Surname VARCHAR(55) NOT NULL,
    Email VARCHAR(254) NOT NULL,
    PhoneNumber VARCHAR(15) NOT NULL,
    Pesel VARCHAR(11) NOT NULL,
    ManagerID INTEGER,
    CONSTRAINT fk_manager FOREIGN KEY (ManagerID) REFERENCES Manager(ID)
);

CREATE TABLE IF NOT EXISTS Specialization (
    ID SERIAL PRIMARY KEY,
    Name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS DoctorSpecialization (
    ID SERIAL PRIMARY KEY,
    DoctorID INTEGER,
    SpecializationID INTEGER,
    CONSTRAINT fk_doctor FOREIGN KEY (DoctorID) REFERENCES Doctor(ID),
    CONSTRAINT fk_specialization FOREIGN KEY (SpecializationID) REFERENCES Specialization(ID)
);

CREATE TABLE IF NOT EXISTS Patient (
    ID SERIAL PRIMARY KEY,
    Name VARCHAR(55) NOT NULL,
    Surname VARCHAR(55) NOT NULL,
    Email VARCHAR(254) NOT NULL,
    PhoneNumber VARCHAR(15) NOT NULL
);

CREATE TABLE IF NOT EXISTS Appointment (
    ID SERIAL PRIMARY KEY,
    Date DATE NOT NULL,
    Comment VARCHAR(520),
    DoctorID INTEGER,
    PatientID INTEGER,
    CONSTRAINT fk_doctor FOREIGN KEY (DoctorID) REFERENCES Doctor(ID),
    CONSTRAINT fk_patient FOREIGN KEY (PatientID) REFERENCES Patient(ID)
);

CREATE TABLE IF NOT EXISTS Rating (
    ID SERIAL PRIMARY KEY,
    Satisfaction INTEGER,
    AppointmentID INTEGER,
    CONSTRAINT fk_appointment FOREIGN KEY (AppointmentID) REFERENCES Appointment(ID)
);

CREATE TABLE IF NOT EXISTS Prescription (
    ID SERIAL PRIMARY KEY,
    Code VARCHAR(50) NOT NULL,
    AppointmentID INTEGER,
    CONSTRAINT fk_appointment FOREIGN KEY (AppointmentID) REFERENCES Appointment(ID)
);

CREATE TABLE IF NOT EXISTS Medicine (
    ID SERIAL PRIMARY KEY,
    Name VARCHAR(250) NOT NULL
);

CREATE TABLE IF NOT EXISTS MedicinePrescription (
    ID SERIAL PRIMARY KEY,
    PrescriptionID INTEGER,
    MedicineID INTEGER,
    CONSTRAINT fk_prescription FOREIGN KEY (PrescriptionID) REFERENCES Prescription(ID),
    CONSTRAINT fk_medicine FOREIGN KEY (MedicineID) REFERENCES Medicine(ID)
);


-- MOCK DATA
-- manager
INSERT INTO public.manager (id, name, surname, email, phonenumber) VALUES
(1, 'John', 'Doe', 'john.doe@hospital.com', '123456789'),
(2, 'Emily', 'Smith', 'emily.smith@hospital.com', '987654321'),
(3, 'Adrian', 'Gone', 'adrian.gone@hospital.com', '987654321'),
(4, 'Managus', 'Mag', 'managus.mag@hospital.com', '987654321');
-- doctor
INSERT INTO public.doctor (id, name, surname, email, phonenumber, pesel, managerid) VALUES
(1, 'Alice', 'Brown', 'alice.brown@hospital.com', '123123123', '12345678901', 1),
(2, 'Bob', 'Green', 'bob.green@hospital.com', '321321321', '98765432109', 2),
(3, 'Charlie', 'White', 'charlie.white@hospital.com', '456456456', '45678901234', 1),
(4, 'John', 'Johnson', 'john.johnson@hospital.com', '12315515', '35678901234', 1);
-- specialization
INSERT INTO public.specialization (id, name) VALUES
(1, 'Cardiology'),
(2, 'Dermatology'),
(3, 'Pediatrics'),
(4, 'Skeletonology');
-- doctorspecialization
INSERT INTO public.doctorspecialization (id, doctorid, specializationid) VALUES
(1, 1, 1),  -- Alice is a Cardiologist
(2, 2, 2),  -- Bob is a Dermatologist
(3, 3, 3),  -- Charlie is a Pediatrician
(4, 1, 2);  -- Alice is a Dermatologist as well
-- patient
INSERT INTO public.patient (id, name, surname, email, phonenumber) VALUES
(1, 'David', 'Johnson', 'david.johnson@gmail.com', '111222333'),
(2, 'Eva', 'Taylor', 'eva.taylor@gmail.com', '444555666'),
(3, 'Frank', 'Williams', 'frank.williams@gmail.com', '777888999'),
(4, 'Adrian', 'Lov', 'adrian.lov@gmail.com', '889888998');
-- appointment
INSERT INTO public.appointment (id, date, comment, doctorid, patientid) VALUES
(1, '2024-10-15', 'Regular check-up', 1, 1),  -- David has an appointment with Alice
(2, '2024-10-18', 'Skin rash', 2, 2),        -- Eva has an appointment with Bob
(3, '2024-10-20', 'Child consultation', 3, 3), -- Frank has an appointment with Charlie
(4, '2024-10-16', 'no comment', 1, 2);
-- prescription
INSERT INTO public.prescription (id, code, appointmentid) VALUES
(1, 'RX12345', 1),  -- Prescription for David
(2, 'RX67890', 2),  -- Prescription for Eva
(3, 'RX77890', 3),  -- Prescription for Eva
(4, 'RX97890', 4);  -- Prescription for Eva
-- medicine
INSERT INTO public.medicine (id, name) VALUES
(1, 'Aspirin'),
(2, 'Ibuprofen'),
(3, 'Paracetamol'),
(4, 'Apap');
-- medicineprescription
INSERT INTO public.medicineprescription (id, prescriptionid, medicineid) VALUES
(1, 1, 1),  -- David prescribed Aspirin
(2, 2, 2),  -- Eva prescribed Ibuprofen
(3, 3, 3),
(4, 4, 4);
-- rating
INSERT INTO public.rating (id, satisfaction, appointmentid) VALUES
(1, 5, 1),  -- David rated Alice's appointment as 5
(2, 4, 2),  -- Eva rated Bob's appointment as 4
(3, 1, 4);
