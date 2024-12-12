CREATE function get_appointment_count(patient_id int)
returns int
language plpgsql
AS
$$
declare
    appointment_count integer;
begin
    SELECT COUNT(*) INTO appointment_count
    FROM Appointment a
    WHERE a.PatientID = patient_id;

    return appointment_count;
end;
$$;

CREATE OR REPLACE FUNCTION get_visits(patient_id int)
returns TABLE (
    date DATE,
    doctor_name varchar(55),
    doctor_surname varchar(55),
    comment varchar(520),
    satisfaction int,
    prescription_code varchar(50),
    medicines text
)
LANGUAGE plpgsql
AS
$$
BEGIN
    RETURN QUERY
    SELECT
        a.date,
        d.name,
        d.surname,
        a.comment,
        r.satisfaction,
        p.code AS prescription_code,
        STRING_AGG(m.name, ', ') AS medicines
    FROM appointment a
    LEFT JOIN rating r ON a.id = r.appointmentid
    LEFT JOIN prescription p ON a.id = p.appointmentid
    LEFT JOIN medicineprescription mp ON p.id = mp.prescriptionid
    LEFT JOIN medicine m ON mp.medicineid = m.id
    LEFT JOIN doctor d ON d.id = a.doctorid
    WHERE a.patientid = patient_id
    GROUP BY a.id, d.name, d.surname, a.date, a.comment, a.doctorid, a.patientid, r.satisfaction, p.code;
END
$$;

CREATE OR REPLACE FUNCTION get_available_doctors(
    specializations TEXT[],
    min_specializations INT,
    check_date DATE
)
RETURNS TABLE(
    name VARCHAR(55),
    surname VARCHAR(55)
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT d.name, d.surname
    FROM doctor d
    JOIN (
        SELECT ds.doctorID
        FROM doctorspecialization ds
        JOIN specialization s ON ds.specializationID = s.ID
        WHERE s.name = ANY(specializations)
        GROUP BY ds.doctorID
        HAVING COUNT(DISTINCT s.name) >= min_specializations
    ) AS specializedDoctors ON d.id = specializedDoctors.doctorID
    JOIN (
        SELECT a.doctorID
        FROM appointment a
        WHERE NOT a.date = check_date
    ) AS availableDoctors ON d.id = availableDoctors.doctorID;
END
$$;

CREATE OR REPLACE PROCEDURE add_specializations(
    doctor_id int,
    specializations VARCHAR(100)[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    spec_id int;
    spec_name VARCHAR(100);
BEGIN
    FOREACH spec_name IN ARRAY specializations
    LOOP
        SELECT s.id INTO spec_id FROM specialization s WHERE s.name = spec_name LIMIT 1;
        INSERT INTO doctorspecialization(DoctorID, SpecializationID)
        VALUES(doctor_id, spec_id);
    END LOOP;
END;
$$;

CREATE OR REPLACE PROCEDURE add_medicine(
    medicine_name VARCHAR(250),
    OUT medicine_id int
)
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT ID INTO medicine_id
    FROM Medicine
    WHERE Name = medicine_name;

    IF NOT FOUND THEN
        INSERT INTO medicine(name) VALUES(medicine_name ) RETURNING ID INTO medicine_id;
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE create_prescription(
    appointment_id INTEGER,
    medicine_names VARCHAR[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    prescription_id INTEGER;
    medicine_id INTEGER;
    prescription_code VARCHAR(50);
    medicine_name VARCHAR;
BEGIN
    BEGIN
        prescription_code := md5(random()::text);

        INSERT INTO prescription(Code, AppointmentID)
        VALUES (prescription_code, appointment_id)
        RETURNING ID INTO prescription_id;

        FOREACH medicine_name IN ARRAY medicine_names
        LOOP
            CALL add_medicine(medicine_name, medicine_id);

            INSERT INTO MedicinePrescription (PrescriptionID, MedicineID)
            VALUES (prescription_id, medicine_id);
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE EXCEPTION 'An error occurred during prescription creation. Transaction has been rolled back: %', SQLERRM;
    END;
END;
$$;

CREATE OR REPLACE PROCEDURE cancel_appointment(
    appointment_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    appointment_date DATE;
BEGIN
    SELECT date FROM Appointment a WHERE a.ID = appointment_id INTO appointment_date;

    IF appointment_date > CURRENT_DATE THEN
        DELETE FROM Appointment a WHERE a.ID = appointment_id;
    ELSE
        RAISE EXCEPTION 'Cannot cancel appointments from the past';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION delete_appointment_related()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM Rating r WHERE r.AppointmentID = OLD.ID;

    DELETE FROM MedicinePrescription mp
    WHERE mp.PrescriptionID IN (SELECT ID FROM Prescription p WHERE p.AppointmentID = OLD.ID);

    DELETE FROM Prescription p WHERE p.AppointmentID = OLD.ID;

    RETURN OLD;
END;
$$;

CREATE TRIGGER before_appointment_delete
BEFORE DELETE
ON Appointment
FOR EACH ROW
EXECUTE FUNCTION delete_appointment_related();

CREATE OR REPLACE FUNCTION can_add_appointment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.date < CURRENT_DATE THEN
        RAISE EXCEPTION 'Appointments can only be added in the future';
    END IF;
END;
$$;

CREATE TRIGGER before_appointment_insert
BEFORE INSERT
ON Appointment
FOR EACH ROW
EXECUTE FUNCTION can_add_appointment();

-- Monthly reports
CREATE TABLE IF NOT EXISTS MonthlyReports (
    ID SERIAL PRIMARY KEY,
    ReportMonth INTEGER NOT NULL,
    ReportYear INTEGER NOT NULL,
    Patients INTEGER,
    Doctors INTEGER,
    AvgSatisfaction DECIMAL(3, 2),
    AppointmentsCount INTEGER,
    AvgSpecializationsPerDoctor DECIMAL(3, 2)
);

CREATE OR REPLACE PROCEDURE GenerateMonthlyReport()
LANGUAGE plpgsql
AS $$
DECLARE
    report_month INTEGER := EXTRACT(MONTH FROM CURRENT_DATE);
    report_year INTEGER := EXTRACT(YEAR FROM CURRENT_DATE);
    patients_count INTEGER;
    doctors_count INTEGER;
    avg_satisfaction DECIMAL(3, 2);
    appointments_count INTEGER;
    avg_specializations_per_doctor DECIMAL(3, 2);
BEGIN
    SELECT COUNT(*) INTO patients_count FROM Patient;

    SELECT COUNT(*) INTO doctors_count FROM Doctor;

    SELECT AVG(r.Satisfaction) INTO avg_satisfaction
    FROM Appointment a
    JOIN Rating r ON a.ID = r.AppointmentID
    WHERE EXTRACT(MONTH FROM a.Date) = report_month
      AND EXTRACT(YEAR FROM a.Date) = report_year;

    SELECT COUNT(*) INTO appointments_count
    FROM Appointment
    WHERE EXTRACT(MONTH FROM Date) = report_month
      AND EXTRACT(YEAR FROM Date) = report_year;

    SELECT AVG(spec_count) INTO avg_specializations_per_doctor
    FROM (
        SELECT DoctorID, COUNT(SpecializationID) AS spec_count
        FROM DoctorSpecialization
        GROUP BY DoctorID
    ) AS specialization_counts;

    INSERT INTO MonthlyReports (ReportMonth, ReportYear, Patients, Doctors, AvgSatisfaction, AppointmentsCount, AvgSpecializationsPerDoctor)
    VALUES (
        report_month,
        report_year,
        patients_count,
        doctors_count,
        avg_satisfaction,
        appointments_count,
        avg_specializations_per_doctor
    );

    RAISE NOTICE 'Monthly report for %-% successfully generated', report_month, report_year;
END;
$$;

CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.schedule('Monthly Report Generation',
                     '59 23 $ * *',
                     'CALL GenerateMonthlyReport()');
