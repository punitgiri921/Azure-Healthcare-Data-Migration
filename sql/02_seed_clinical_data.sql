-- ============================================================================
-- SCRIPT 02: Seed Realistic Synthetic Clinical & Financial EMR Data
-- Project: Azure Healthcare Data Migration & Medallion Lakehouse
-- Target: Microsoft SQL Server (.\SQLEXPRESS) / dbo schema
-- ============================================================================

USE healthcare_emr_source;
GO

SET NOCOUNT ON;

-- 1. Seed Providers
PRINT 'Seeding Providers...';
INSERT INTO dbo.providers (provider_name, specialty, department, npi_number, created_at, updated_at) VALUES
('Dr. Sarah Lin, MD', 'Cardiology', 'Cardiology Clinic', '1093847291', '2024-01-01 08:00:00', '2024-01-01 08:00:00'),
('Dr. Marcus Vance, DO', 'Internal Medicine', 'General Inpatient', '1827364519', '2024-01-01 08:00:00', '2024-01-01 08:00:00'),
('Dr. Elena Rostova, MD', 'Orthopedic Surgery', 'Surgical Pavilion', '1928374650', '2024-01-01 08:00:00', '2024-01-01 08:00:00'),
('Dr. Aisha Patel, MD', 'Pediatrics', 'Childrens Pavilion', '1472583690', '2024-01-01 08:00:00', '2024-01-01 08:00:00'),
('Dr. James Sterling, MD', 'Emergency Medicine', 'Emergency Department', '1357924680', '2024-01-01 08:00:00', '2024-01-01 08:00:00'),
('Dr. Hannah Kim, MD', 'Neurology', 'Neurology Outpatient', '1029384756', '2024-01-01 08:00:00', '2024-01-01 08:00:00'),
('Dr. Carlos Mendoza, MD', 'Oncology', 'Cancer Center', '1648293750', '2024-01-01 08:00:00', '2024-01-01 08:00:00'),
('Dr. Rebecca Taylor, DO', 'Pulmonology', 'Pulmonary Critical Care', '1182736450', '2024-01-01 08:00:00', '2024-01-01 08:00:00'),
('Dr. Robert Chen, MD', 'Gastroenterology', 'Digestive Health', '1738291045', '2024-01-01 08:00:00', '2024-01-01 08:00:00'),
('Dr. Olivia Davis, MD', 'Endocrinology', 'Diabetes & Endocrinology', '1892038471', '2024-01-01 08:00:00', '2024-01-01 08:00:00');
GO

-- 2. Seed Patients (Synthetic PII for HIPAA de-identification testing)
PRINT 'Seeding Patients...';
INSERT INTO dbo.patients (first_name, last_name, ssn, dob, gender, address, city, state, zip, insurance_id, created_at, updated_at) VALUES
('John', 'Mitchell', '984-21-4920', '1968-04-12', 'Male', '742 Evergreen Terrace', 'Springfield', 'IL', '62704', 'BCBS-938201', '2024-01-05 09:12:00', '2024-01-05 09:12:00'),
('Mary', 'Higgins', '912-34-5678', '1975-09-24', 'Female', '124 Conch Street', 'Bikini', 'HI', '96815', 'AET-482019', '2024-01-06 10:15:00', '2024-01-06 10:15:00'),
('Arthur', 'Pendleton', '933-72-1092', '1952-11-03', 'Male', '221B Baker Street', 'Boston', 'MA', '02108', 'MEDICARE-A7281', '2024-01-07 11:30:00', '2024-01-07 11:30:00'),
('Emily', 'Watson', '901-44-8832', '1989-02-18', 'Female', '31 Spooner Street', 'Quahog', 'RI', '02860', 'UHC-109283', '2024-01-08 14:20:00', '2024-01-08 14:20:00'),
('David', 'Kowalski', '944-12-9051', '1961-07-30', 'Male', '404 Elm Street', 'Dallas', 'TX', '75201', 'CIGNA-837192', '2024-01-09 15:45:00', '2024-01-09 15:45:00'),
('Sophia', 'Alvarez', '920-88-3419', '1995-12-05', 'Female', '88 Maple Ave', 'Phoenix', 'AZ', '85001', 'AET-772910', '2024-01-10 08:30:00', '2024-01-10 08:30:00'),
('William', 'Foster', '955-63-2210', '1948-03-14', 'Male', '1600 Oak Ridge Rd', 'Denver', 'CO', '80201', 'MEDICARE-B9921', '2024-01-11 09:50:00', '2024-01-11 09:50:00'),
('Grace', 'Hopper', '966-19-4821', '1982-08-22', 'Female', '42 Wallaby Way', 'Seattle', 'WA', '98101', 'BCBS-110293', '2024-01-12 11:15:00', '2024-01-12 11:15:00'),
('Daniel', 'Jackson', '977-38-5912', '1971-05-19', 'Male', '710 Stargate Blvd', 'Colorado Springs', 'CO', '80903', 'TRICARE-82910', '2024-01-13 13:00:00', '2024-01-13 13:00:00'),
('Chloe', 'Bennett', '988-51-7743', '2001-10-09', 'Female', '505 Vineyard Lane', 'Napa', 'CA', '94558', 'KAISER-93821', '2024-01-14 14:10:00', '2024-01-14 14:10:00'),
('George', 'Hamilton', '911-22-3344', '1959-01-29', 'Male', '12 Lakeview Dr', 'Minneapolis', 'MN', '55401', 'MEDICARE-C1029', '2024-01-15 16:30:00', '2024-01-15 16:30:00'),
('Samantha', 'Reed', '922-33-4455', '1992-06-17', 'Female', '840 Sunset Blvd', 'Los Angeles', 'CA', '90028', 'UHC-554433', '2024-01-16 09:00:00', '2024-01-16 09:00:00'),
('Lucas', 'Gray', '933-44-5566', '1985-11-11', 'Male', '210 River Street', 'Portland', 'OR', '97201', 'BCBS-667788', '2024-01-17 10:45:00', '2024-01-17 10:45:00'),
('Natalie', 'Portman', '944-55-6677', '1979-03-03', 'Female', '99 Ocean View', 'Miami', 'FL', '33101', 'CIGNA-123987', '2024-01-18 12:15:00', '2024-01-18 12:15:00'),
('Henry', 'Cavill', '955-66-7788', '1983-05-05', 'Male', '33 Metropolis Way', 'New York', 'NY', '10001', 'AET-998877', '2024-01-19 14:00:00', '2024-01-19 14:00:00'),
('Victoria', 'Beckham', '966-77-8899', '1974-04-17', 'Female', '77 Fashion Ave', 'Atlanta', 'GA', '30301', 'UHC-778899', '2024-01-20 15:20:00', '2024-01-20 15:20:00'),
('Benjamin', 'Franklin', '977-88-9900', '1965-09-08', 'Male', '1776 Liberty St', 'Philadelphia', 'PA', '19104', 'BCBS-177600', '2024-01-21 08:45:00', '2024-01-21 08:45:00'),
('Olivia', 'Wilde', '988-99-0011', '1984-03-10', 'Female', '45 Broadway', 'Nashville', 'TN', '37201', 'CIGNA-454545', '2024-01-22 10:10:00', '2024-01-22 10:10:00'),
('Alexander', 'Hamilton', '999-00-1122', '1955-01-11', 'Male', '10 Treasury Rd', 'Richmond', 'VA', '23219', 'MEDICARE-D5544', '2024-01-23 11:40:00', '2024-01-23 11:40:00'),
('Emma', 'Stone', '900-11-2233', '1988-11-06', 'Female', '62 Hollywood Blvd', 'San Diego', 'CA', '92101', 'KAISER-626262', '2024-01-24 13:25:00', '2024-01-24 13:25:00');
GO

-- 3. Seed Encounters
PRINT 'Seeding Encounters...';
INSERT INTO dbo.encounters (patient_id, provider_id, admission_date, discharge_date, encounter_type, department, discharge_disposition, created_at, updated_at) VALUES
(1001, 101, '2024-02-01 09:00:00', '2024-02-03 14:00:00', 'Inpatient', 'Cardiology', 'Home', '2024-02-03 15:00:00', '2024-02-03 15:00:00'),
(1002, 105, '2024-02-02 18:30:00', '2024-02-02 23:15:00', 'Emergency', 'Emergency Department', 'Home', '2024-02-02 23:30:00', '2024-02-02 23:30:00'),
(1003, 102, '2024-02-04 10:00:00', '2024-02-08 11:30:00', 'Inpatient', 'General Inpatient', 'Home', '2024-02-08 12:00:00', '2024-02-08 12:00:00'),
(1004, 104, '2024-02-05 14:15:00', '2024-02-05 15:00:00', 'Outpatient', 'Pediatrics', 'Home', '2024-02-05 15:30:00', '2024-02-05 15:30:00'),
(1005, 103, '2024-02-06 07:30:00', '2024-02-07 16:00:00', 'Inpatient', 'Surgical Pavilion', 'Home', '2024-02-07 16:30:00', '2024-02-07 16:30:00'),
(1006, 106, '2024-02-08 11:00:00', '2024-02-08 12:00:00', 'Outpatient', 'Neurology Outpatient', 'Home', '2024-02-08 12:30:00', '2024-02-08 12:30:00'),
(1007, 107, '2024-02-09 08:45:00', '2024-02-09 17:00:00', 'Outpatient', 'Cancer Center', 'Home', '2024-02-09 17:30:00', '2024-02-09 17:30:00'),
(1008, 108, '2024-02-10 13:20:00', '2024-02-14 10:00:00', 'Inpatient', 'Pulmonary Critical Care', 'Transferred', '2024-02-14 10:30:00', '2024-02-14 10:30:00'),
(1009, 109, '2024-02-11 09:30:00', '2024-02-11 13:00:00', 'Outpatient', 'Digestive Health', 'Home', '2024-02-11 13:30:00', '2024-02-11 13:30:00'),
(1010, 110, '2024-02-12 15:00:00', '2024-02-12 16:00:00', 'Telehealth', 'Diabetes & Endocrinology', 'Home', '2024-02-12 16:15:00', '2024-02-12 16:15:00'),
(1011, 101, '2024-02-13 10:30:00', '2024-02-13 11:30:00', 'Outpatient', 'Cardiology Clinic', 'Home', '2024-02-13 12:00:00', '2024-02-13 12:00:00'),
(1012, 105, '2024-02-14 21:00:00', '2024-02-15 04:00:00', 'Emergency', 'Emergency Department', 'Home', '2024-02-15 04:30:00', '2024-02-15 04:30:00'),
(1013, 103, '2024-02-16 08:00:00', '2024-02-18 12:00:00', 'Inpatient', 'Surgical Pavilion', 'Home', '2024-02-18 12:30:00', '2024-02-18 12:30:00'),
(1014, 102, '2024-02-17 14:00:00', '2024-02-17 15:00:00', 'Telehealth', 'General Inpatient', 'Home', '2024-02-17 15:30:00', '2024-02-17 15:30:00'),
(1015, 108, '2024-02-19 06:15:00', '2024-02-23 15:00:00', 'Inpatient', 'Pulmonary Critical Care', 'Home', '2024-02-23 15:30:00', '2024-02-23 15:30:00');
GO

-- 4. Seed Diagnoses (ICD-10 Mappings)
PRINT 'Seeding Diagnoses...';
INSERT INTO dbo.diagnoses (encounter_id, icd10_code, diagnosis_description, is_primary, created_at, updated_at) VALUES
(5001, 'I21.9', 'Acute myocardial infarction, unspecified', 1, '2024-02-01 10:00:00', '2024-02-01 10:00:00'),
(5001, 'I10', 'Essential (primary) hypertension', 0, '2024-02-01 10:00:00', '2024-02-01 10:00:00'),
(5002, 'R07.9', 'Chest pain, unspecified', 1, '2024-02-02 19:00:00', '2024-02-02 19:00:00'),
(5003, 'J18.9', 'Pneumonia, unspecified organism', 1, '2024-02-04 11:00:00', '2024-02-04 11:00:00'),
(5003, 'E11.9', 'Type 2 diabetes mellitus without complications', 0, '2024-02-04 11:00:00', '2024-02-04 11:00:00'),
(5004, 'J02.9', 'Acute pharyngitis, unspecified', 1, '2024-02-05 14:30:00', '2024-02-05 14:30:00'),
(5005, 'M16.11', 'Unilateral primary osteoarthritis, right hip', 1, '2024-02-06 08:00:00', '2024-02-06 08:00:00'),
(5006, 'G43.909', 'Migraine, unspecified, not intractable', 1, '2024-02-08 11:30:00', '2024-02-08 11:30:00'),
(5007, 'C50.919', 'Malignant neoplasm of unspecified site of breast', 1, '2024-02-09 09:15:00', '2024-02-09 09:15:00'),
(5008, 'J44.1', 'Chronic obstructive pulmonary disease with acute exacerbation', 1, '2024-02-10 14:00:00', '2024-02-10 14:00:00'),
(5009, 'K21.9', 'Gastro-esophageal reflux disease without esophagitis', 1, '2024-02-11 10:00:00', '2024-02-11 10:00:00'),
(5010, 'E10.9', 'Type 1 diabetes mellitus without complications', 1, '2024-02-12 15:30:00', '2024-02-12 15:30:00'),
(5011, 'I48.91', 'Unspecified atrial fibrillation', 1, '2024-02-13 11:00:00', '2024-02-13 11:00:00'),
(5012, 'S83.511A', 'Sprain of anterior cruciate ligament of right knee, initial', 1, '2024-02-14 21:30:00', '2024-02-14 21:30:00'),
(5013, 'M17.11', 'Unilateral primary osteoarthritis, right knee', 1, '2024-02-16 08:30:00', '2024-02-16 08:30:00'),
(5014, 'E66.9', 'Obesity, unspecified', 1, '2024-02-17 14:30:00', '2024-02-17 14:30:00'),
(5015, 'J45.901', 'Unspecified asthma with (acute) exacerbation', 1, '2024-02-19 07:00:00', '2024-02-19 07:00:00');
GO

-- 5. Seed Claims (Financial / Billing Data)
PRINT 'Seeding Claims...';
INSERT INTO dbo.claims (encounter_id, billed_amount, paid_amount, claim_status, denial_reason, submitted_date, paid_date, created_at, updated_at) VALUES
(5001, 28500.00, 24200.00, 'Approved', NULL, '2024-02-05', '2024-02-20', '2024-02-05 16:00:00', '2024-02-20 11:00:00'),
(5002, 3200.00, 2750.00, 'Approved', NULL, '2024-02-04', '2024-02-18', '2024-02-04 10:00:00', '2024-02-18 14:00:00'),
(5003, 14200.00, 11800.00, 'Approved', NULL, '2024-02-10', '2024-02-25', '2024-02-10 11:00:00', '2024-02-25 15:00:00'),
(5004, 450.00, 380.00, 'Approved', NULL, '2024-02-07', '2024-02-19', '2024-02-07 12:00:00', '2024-02-19 09:30:00'),
(5005, 38400.00, 0.00, 'Denied', 'Pre-authorization missing', '2024-02-09', NULL, '2024-02-09 14:00:00', '2024-02-22 16:00:00'),
(5006, 1250.00, 1050.00, 'Approved', NULL, '2024-02-10', '2024-02-24', '2024-02-10 13:00:00', '2024-02-24 10:00:00'),
(5007, 9800.00, 8300.00, 'Approved', NULL, '2024-02-11', '2024-02-26', '2024-02-11 15:00:00', '2024-02-26 12:00:00'),
(5008, 22100.00, 18700.00, 'Approved', NULL, '2024-02-16', '2024-03-02', '2024-02-16 11:00:00', '2024-03-02 14:00:00'),
(5009, 1850.00, 1550.00, 'Approved', NULL, '2024-02-13', '2024-02-27', '2024-02-13 12:00:00', '2024-02-27 10:30:00'),
(5010, 320.00, 270.00, 'Approved', NULL, '2024-02-14', '2024-02-28', '2024-02-14 16:30:00', '2024-02-28 11:15:00'),
(5011, 1400.00, 1180.00, 'Approved', NULL, '2024-02-15', '2024-03-01', '2024-02-15 13:00:00', '2024-03-01 09:45:00'),
(5012, 4500.00, 0.00, 'Pending', NULL, '2024-02-17', NULL, '2024-02-17 10:00:00', '2024-02-17 10:00:00'),
(5013, 34200.00, 29100.00, 'Approved', NULL, '2024-02-20', '2024-03-06', '2024-02-20 14:00:00', '2024-03-06 13:00:00'),
(5014, 280.00, 230.00, 'Approved', NULL, '2024-02-19', '2024-03-04', '2024-02-19 11:00:00', '2024-03-04 10:00:00'),
(5015, 19600.00, 16400.00, 'Approved', NULL, '2024-02-25', '2024-03-10', '2024-02-25 15:00:00', '2024-03-10 14:30:00');
GO

-- 6. Seed Watermark Control Table (Initial Baseline = 1970-01-01)
PRINT 'Initializing Watermark Control Table...';
INSERT INTO dbo.etl_watermark_control (table_name, watermark_column, last_watermark_value, status, last_run_timestamp) VALUES
('patients', 'updated_at', '1970-01-01 00:00:00.000', 'READY', NULL),
('providers', 'updated_at', '1970-01-01 00:00:00.000', 'READY', NULL),
('encounters', 'updated_at', '1970-01-01 00:00:00.000', 'READY', NULL),
('diagnoses', 'updated_at', '1970-01-01 00:00:00.000', 'READY', NULL),
('claims', 'updated_at', '1970-01-01 00:00:00.000', 'READY', NULL);
GO

PRINT 'Synthetic EMR clinical & financial data seeded successfully!';
GO
