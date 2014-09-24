

--1: Load new Procedure Codes. See banner join issues.docx
--  This has SQL to insert all new proc codes into a temp table.

--2: Load new Diagnosis Codes. Again, see banner join issues.docx

--3: Load new Doctors (Doctors for new patients, which dont exist in our system)

WITH new_patients AS -- CTE for new patients.
(
	SELECT DISTINCT ng.person_identifier, 
					ng.Admitting_Physician_ID,
					ng.Admitting_Physician_First_Name,
					ng.Admitting_Physician_Last_Name,
					ng.Admitting_Physician_Middle_Initial
	FROM heartland_staff.dbo.nextgen ng
	WHERE NOT EXISTS
	(
		SELECT * FROM patient.dbo.patient p
		WHERE p.patient_mrn = ng.person_identifier
		AND p.system_id = 444
	)
)

SELECT DISTINCT np.Admitting_Physician_ID
FROM new_patients np
WHERE NOT EXISTS
(
	SELECT * FROM patient.dbo.doctor d
	WHERE d.local_doctor_id = np.Admitting_Physician_ID
	AND d.system_id = 444
)

----------Returns list of doctors with Name Inconsistencies--------------
-- Only Doctor that we have to add (for new patient): '1881623643'
WITH a AS
(
	SELECT  DISTINCT Admitting_Physician_ID,
					Admitting_Physician_First_Name,
					Admitting_Physician_Last_Name,
					Admitting_Physician_Middle_Initial
	FROM heartland_staff.dbo.nextgen
)
SELECT	DISTINCT n.Admitting_Physician_ID,
		n.Admitting_Physician_First_Name,
		n.Admitting_Physician_Last_Name,
		n.Admitting_Physician_Middle_Initial
FROM heartland_staff.dbo.nextgen n
JOIN a ON (a.Admitting_Physician_ID = n.admitting_physician_id
	AND (a.Admitting_Physician_First_Name != n.admitting_physician_first_name
		OR a.Admitting_Physician_Last_Name != n.Admitting_Physician_Last_Name
		OR a.Admitting_Physician_Middle_Initial != n.Admitting_Physician_Middle_Initial)
	AND a.Admitting_Physician_ID != '')
ORDER BY n.Admitting_Physician_ID


----------------------------------------------
-- Insert data for new patients into Patient Table.
-- 3 patients have Race data that is inconsistent across rows. 
-- those are person_identifier: 1586510, 451166, 57489
-- Use this query to get those.
WITH a AS
(
SELECT DISTINCT ng.person_identifier, 
				ng.first_name,
				ng.last_name,
				ng.middle_name,
				ng.DOB,
				ng.Gender,
				ng.Race,
				ng.Ethnicity,
				ng.Patient_prefix,
				ng.Patient_Suffix,
				ng.Death_date
FROM heartland_staff.dbo.nextgen ng
WHERE NOT EXISTS
(
	SELECT * FROM patient.dbo.patient p
	WHERE p.patient_mrn = ng.person_identifier
	AND p.system_id = 444
)
)
SELECT DISTINCT ng.person_identifier, 
				ng.first_name,
				ng.last_name,
				ng.middle_name,
				ng.DOB,
				ng.Gender,
				ng.Race,
				ng.Ethnicity,
				ng.Patient_prefix,
				ng.Patient_Suffix,
				ng.Death_date
FROM heartland_staff.dbo.nextgen ng
JOIN a on a.person_identifier = ng.person_identifier
AND (a.first_name != ng.first_name OR
	a.last_name != ng.last_name OR
	a.middle_name != ng.middle_name OR
	a.DOB != ng.DOB OR
	a.Gender != ng.Gender OR
	a.Race != ng.Race OR
	a.Ethnicity != ng.Ethnicity OR
	a.Patient_prefix != ng.Patient_prefix OR
	a.Patient_Suffix != ng.Patient_Suffix OR
	a.Death_date != ng.Death_date)
ORDER BY ng.person_identifier

/*
-As for the actual data insert, once those 3 patients
are resolved, just select the data and insert it into patient.

Put the patient_identifiers into a temp table, to be used
for patient_address and patient_contact

SQL below:
*/
CREATE TABLE new_patients
(
	person_identifier int
)
INSERT INTO new_patients (person_identifier)
SELECT DISTINCT person_identifier
FROM heartland_staff.dbo.nextgen ng
WHERE NOT EXISTS
(
	SELECT * FROM patient.dbo.patient
	WHERE patient_mrn = ng.person_identifier
	AND system_id = 444
)

SELECT DISTINCT ng.person_identifier, -- data select for patient table insert
				ng.first_name,
				ng.last_name,
				ng.middle_name,
				ng.DOB,
				ng.Gender,
				ng.Race,
				ng.Ethnicity,
				ng.Patient_prefix,
				ng.Patient_Suffix,
				ng.Death_date
FROM heartland_staff.dbo.nextgen ng
WHERE NOT EXISTS
(
	SELECT * FROM patient.dbo.patient p
	WHERE p.patient_mrn = ng.person_identifier
	AND p.system_id = 444
)

-------------------------------------------------------------
/*
--Insert patient contact info for new patients.

-- We will be referencing the temp table created above with
	the person_identifier for new patients we just inserted.
	
-- Ask banner how to handle multiple phone numbers. 
		-- Could just take the most recent one. 

-- Is it safe to set all of these contact types as Phone?
*/
WITH a AS -- Get list of patients with multiple different phone numbers
(
	SELECT DISTINCT
					ng.PhoneNumber,
					ng.person_identifier 
	FROM heartland_staff.dbo.nextgen ng
	JOIN new_patients np 
	ON np.person_identifier = ng.person_identifier
)
SELECT distinct ng.person_identifier, ng.PhoneNumber
FROM heartland_staff.dbo.nextgen ng
JOIN a ON a.person_identifier = ng.person_identifier
WHERE a.PhoneNumber != ng.PhoneNumber
ORDER BY ng.person_identifier

/*
	Select for the actual insert to patient_contact.
	Look at this again once we have resolved the 
	multiple phone number issue. 
*/
SELECT DISTINCT p.patient_ID, 
				ng.phonenumber,
				ng.person_identifier
FROM heartland_staff.dbo.nextgen ng
JOIN new_patients np ON np.person_identifier = ng.person_identifier
JOIN patient.dbo.patient p ON p.patient_mrn = ng.person_identifier


------------------------------------------------------
/*
	Insert patient_adddress data for those new patients.
	
	There is 1 new patient with multiple addresses:
	person_identifier 1010201
*/
SELECT DISTINCT ng.person_identifier, -- select statement for insert
				ng.Patient_Address_1, 
				ng.Patient_Address_2,
				ng.Patient_City, 
				ng.Patient_State,
				ng.Patient_ZipCode
FROM heartland_staff.dbo.nextgen ng
JOIN new_patients np 
ON np.person_identifier = ng.person_identifier

WITH a AS -- SQL for getting data for multiple address entries.
(
	SELECT DISTINCT ng.person_identifier,
					ng.Patient_Address_1, 
					ng.Patient_Address_2,
					ng.Patient_City, 
					ng.Patient_State,
					ng.Patient_ZipCode
	FROM heartland_staff.dbo.nextgen ng
	JOIN new_patients np 
	ON np.person_identifier = ng.person_identifier
)
SELECT DISTINCT ng.person_identifier 
FROM heartland_staff.dbo.nextgen ng
JOIN a ON a.person_identifier =ng.person_identifier
WHERE 
(
	a.Patient_Address_1 != ng.Patient_Address_1 OR
	a.Patient_Address_2 != ng.Patient_Address_2 OR
	a.Patient_City != ng.Patient_City OR
	a.Patient_State != ng.Patient_State OR
	a.Patient_ZipCode != ng.Patient_ZipCode
)

------------------------------------------------------
/*
	Insert data to patient_visit
	
	-- Still need Banner to give update on duplicate visit_ids
		because those are still in the data.
		
	-- There are 3138866 distinct visit ids in nextgen table. 
	
	-- Need to check and confirm counts for this once the dups 
		are handled for visit_id
*/
SELECT DISTINCT p.patient_id, ng.visit_id
FROM patient.dbo.patient p
JOIN heartland_staff.dbo.nextgen ng
ON ng.person_identifier = p.patient_mrn
WHERE p.system_id = 444


--------------------------------------------------------------
/*
	Insert patient_visit_status data
*/

SELECT pv.patient_visit_id, 
		ng.admission_date, 
		ng.facility
FROM patient.dbo.patient_visit pv
JOIN patient.dbo.patient p 
		ON p.patient_id = pv.patient_id
JOIN heartland_staff.dbo.nextgen ng
		ON ng.person_identifier = p.patient_mrn 
		AND pv.visit_num = ng.visit_id
WHERE p.system_id = 444

----------------------------------------------------------
/*
	Insert patient_visit_procedure data
*/
-- Select statement for the insert. 
-- Will have to run this for each of the procedure code columns.
SELECT pvs.patient_visit_status_id, pc.procedure_code_id
FROM patient.dbo.patient_visit_status pvs
JOIN patient.dbo.patient_visit pv
		ON pv.patient_visit_id = pvs.patient_visit_id
JOIN patient.dbo.patient p
		ON p.patient_id = pv.patient_id
JOIN heartland_staff.dbo.nextgen ng
		ON ng.person_identifier = p.patient_mrn
		AND ng.visit_id = pv.visit_num
JOIN patient.dbo.procedure_code pc
		ON pc.code = ng.Procedure_Codes1
WHERE p.system_id = 444 AND ng.Procedure_Codes1 != ''
	

---------------------------------------------------
/*
	Insert patient_visit_diagnosis data
*/
-- Will have to run this for each of the diagnosis code columns.
SELECT pvs.patient_visit_status_id, dc.diagnosis_code_id
FROM patient.dbo.patient_visit_status pvs
JOIN patient.dbo.patient_visit pv
		ON pv.patient_visit_id = pvs.patient_visit_id
JOIN patient.dbo.patient p
		ON p.patient_id = pv.patient_id
JOIN heartland_staff.dbo.nextgen ng
		ON ng.person_identifier = p.patient_mrn
		AND ng.visit_id = pv.visit_num
JOIN patient.dbo.diagnosis_code dc
		ON dc.code = ng.Diagnostic_Codes1
WHERE p.system_id = 444

