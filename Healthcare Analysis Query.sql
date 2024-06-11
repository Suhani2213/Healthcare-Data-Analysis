select * from Patients;
select * from Transactions;
select * from AppointmentDetails;
select * from HealthcareProfessionals;
select * from MedicationsPrescribed;
select * from PatientRecords;


-- Appointment and Patient Data
-- Can we see a list of all our patients along with the date of their last appointment?
SELECT 
    p.PatientID,
    p.FullName,
    MAX(ad.AppointmentDate) Last_AppointmentDate
FROM
    Patients p
        INNER JOIN
    AppointmentDetails ad ON p.PatientID = ad.PatientID
GROUP BY p.PatientID , p.FullName;


-- What's the total amount we've charged each patient?
SELECT 
    p.PatientID, p.FullName, SUM(t.AmountCharged) Total_Amount
FROM
    Patients p
        INNER JOIN
    Transactions t ON p.PatientID = t.PatientID
GROUP BY p.PatientID , p.FullName
ORDER BY SUM(t.AmountCharged) DESC;


-- Which medication do we prescribe the most, and how often?
SELECT 
    MedicationName, COUNT(1) AS Most_Prescribed_Medicine
FROM
    MedicationsPrescribed
GROUP BY MedicationName
ORDER BY Most_Prescribed_Medicine DESC
LIMIT 1;
 

-- How do we rank our patients by the number of their appointments?
SELECT p.PatientID, p.FullName,
       COUNT(a.AppointmentID) AS no_of_appointment,
       ROW_NUMBER() OVER(ORDER BY COUNT(a.AppointmentID) DESC) PatientRank
FROM AppointmentDetails a
INNER JOIN Patients p
 ON a.PatientID = p.PatientID
GROUP BY p.PatientID;
 

-- Who are our patients that haven't booked any appointments yet?
SELECT 
    p.PatientID, p.FullName
FROM
    Patients p
        LEFT JOIN
    AppointmentDetails ad ON p.PatientID = ad.PatientID
WHERE
    ad.AppointmentID = 'NULL';
 
 
 -- Can we track the next appointment date for each patient?
SELECT *
FROM (SELECT p.PatientID,FullName, AppointmentDate LastAppointmentDate,
      LEAD(AppointmentDate) OVER(PARTITION BY PatientID ORDER BY AppointmentDate) NextAppointmentDate
	  FROM appointmentdetails a
      RIGHT JOIN patients p
      ON a.PatientID = p.PatientID
	  ORDER BY PatientID, LastAppointmentDate) a
WHERE NextAppointmentDate is not null;


-- Which healthcare professionals haven't seen any patients?
SELECT 
    hp.Name,
    AppointmentID,
    COALESCE(AppointmentID, 0) AS Patients_Attended
FROM
    HealthcareProfessionals hp
        LEFT JOIN
    AppointmentDetails ap ON hp.Name = ap.HealthcareProfessional
WHERE
    AppointmentID IS NULL;
 

-- Can we identify patients who had back-to-back appointments within a 30-day period?
With AppointmentInfo as (
SELECT p.PatientID, FullName, AppointmentDate,
LEAD(AppointmentDate) OVER(PARTITION BY PatientID ORDER BY AppointmentDate) NextAppointmentDate
FROM appointmentdetails a
JOIN patients p
ON a.PatientID = p.PatientID
)
SELECT *
From AppointmentInfo
WHERE DATEDIFF(NextAppointmentDate, AppointmentDate) <= 30;
 

-- What's the average charge per appointment for each healthcare professional?
SELECT 
    HealthcareProfessional,
    ROUND(AVG(AmountCharged)) AS Average_Charge
FROM
    AppointmentDetails a
        JOIN
    Transactions t ON t.PatientID = a.PatientID
GROUP BY HealthcareProfessional;
 

-- Medication and Revenue Analysis
-- Who's the last patient each healthcare professional saw, and when?
WITH PatientNO_ProfessionalWise AS (
SELECT a.HealthcareProfessional, a.AppointmentDate, p.PatientID, FullName,
DENSE_RANK() OVER (PARTITION BY a.HealthcareProfessional ORDER BY a.AppointmentDate DESC) AS Patient_Rank
FROM appointmentdetails a
JOIN patients p
ON a.PatientID = p.PatientID
)
SELECT PatientID, FullName, HealthcareProfessional, AppointmentDate
FROM PatientNO_ProfessionalWise
WHERE Patient_Rank = 1
ORDER BY AppointmentDate DESC;
 

-- Which of our patients have been prescribed insulin?
SELECT 
    p.PatientID, FullName, MedicationName
FROM
    MedicationsPrescribed m
        JOIN
    appointmentdetails a ON a.AppointmentID = m.AppointmentID
        JOIN
    patients p ON a.PatientID = p.PatientID
WHERE
    MedicationName LIKE '%Insulin%';
 

-- How can we calculate the total amount charged and the number of appointments for each patient?
SELECT 
    FullName,
    SUM(AmountCharged) AmountCharged,
    COUNT(a.AppointmentID) AppointmentCount
FROM
    transactions t
        RIGHT JOIN
    appointmentdetails a ON a.PatientID = t.PatientID
        AND a.AppointmentDate = t.TransactionDate
        RIGHT JOIN
    patients p ON p.patientid = a.patientid
GROUP BY p.PatientID , FullName
ORDER BY AmountCharged DESC;
 

-- Can we rank our healthcare professionals by the number of unique patients they've seen?
WITH Patient_attended as (
SELECT Name, COUNT( DISTINCT PatientID) as Patient_Count
FROM HealthcareProfessionals h
LEFT JOIN appointmentdetails a
ON a.HealthcareProfessional = h.Name
GROUP BY Name
)
SELECT Name,
	   RANK () OVER (ORDER BY Patient_Count DESC) as "Dr.Rank"
FROM Patient_attended;
 

-- Advanced Analysis with Subqueries and CTEs
-- How does each patient's appointment count compare to the clinic's average?
WITH AVG_times_patient_visit as (
select PatientID, FullName,
AVG(AppointmentCount) OVER ()PatientAverageVisitCount,
AppointmentCOUNT
from (
	  select a.PatientID, FullName, COUNT(1) as AppointmentCOUNT
      from  appointmentdetails a
      RIGHT join Patients p ON a.PatientID = p.PatientID
      GROUP BY PatientID, FullName) AppointmentCounts
)
select FullName,
	   CASE
          WHEN AppointmentCOUNT > PatientAverageVisitCount THEN "above average"
          WHEN AppointmentCOUNT = PatientAverageVisitCount THEN "at par"
          ELSE "below average"
	 END AS Patient_category
from  AVG_times_patient_visit
ORDER BY Patient_category;
 
 
-- For patients without transactions, can we ensure their total charged amount shows up as zero instead of NULL?
SELECT FullName, 
       COUNT(t.TransactionID) AS NumAppointments,
       COALESCE(SUM(t.AmountCharged), 0) AS TotalAmountCharged
FROM Patients p
LEFT JOIN transactions t
ON p.PatientID = t.PatientID
GROUP BY p.PatientID, FullName
HAVING COUNT(t.TransactionID) is null;
 

-- What's the most common medication for each type of diabetes we treat?
WITH TimesMedicinePrescribed as (
SELECT DiabetesType, MedicationName, COUNT(MedicationName) MedicinePrescribedCount
FROM PatientRecords p
LEFT JOIN AppointmentDetails a ON a.PatientID = p.PatientID
JOIN MedicationsPrescribed m ON m.AppointmentID = a.AppointmentID
GROUP BY DiabetesType, MedicationName
), CommonlyUsedMedecineRank as (
SELECT DiabetesType, MedicationName,
DENSE_RANK () Over (PARTITION BY DiabetesType ORDER BY MedicinePrescribedCount DESC) CommonlyUsedMed
FROM TimesMedicinePrescribed
)
SELECT DiabetesType, MedicationName
FROM CommonlyUsedMedecineRank
WHERE CommonlyUsedMed = 1;
 

-- We see the growth in appointment numbers from month to month?
WITH AppointmentCount AS (
SELECT CONCAT(YEAR(AppointmentDate),' - ', Month(AppointmentDate)) months,
	   COUNT(AppointmentID) Appointment_This_Month
FROM AppointmentDetails
GROUP BY months
), AppointmentCount_LastMonth as (
SELECT *,
LAG(Appointment_This_Month) OVER (ORDER BY months) Appointment_Previous_Month
FROM AppointmentCount
)
SELECT *,
Appointment_This_Month - Appointment_Previous_Month month_on_month_growth
FROM AppointmentCount_LastMonth;
 

-- How do healthcare professionals' appointments and revenue compare?
SELECT 
    HealthcareProfessional,
    SUM(AmountCharged) Total_Revenue,
    COUNT(AppointmentID) Patient_Seen
FROM
    AppointmentDetails a
        JOIN
    Transactions t ON t.PatientID = a.PatientID
        AND t.TransactionDate = a.AppointmentDate
GROUP BY HealthcareProfessional
ORDER BY COUNT(AppointmentID) DESC;
 

-- Which medications have seen a change in their prescribing rank from month to month?
WITH medicineprescribedovermonth as (
select CONCAT(YEAR(a.AppointmentDate),'-',MONTH(a.AppointmentDate)) monthnumber, m.MedicationName, COUNT(m.MedicationName) medicinecount
from MedicationsPrescribed m
JOIN AppointmentDetails a
ON a.AppointmentID = m.AppointmentID
GROUP BY CONCAT(YEAR(a.AppointmentDate),'-',MONTH(a.AppointmentDate)), MedicationName
), ranked as (
SELECT monthnumber, MedicationName, medicinecount,
DENSE_RANK () Over (PartitION BY monthnumber ORDER BY medicinecount DESC) NextMonthRank
FROM medicineprescribedovermonth
ORDER BY monthnumber
)
SELECT monthnumber, MedicationName,
LEAD(NextMonthRank) OVER (PARTITION BY MedicationName ORDER BY monthnumber) NextMonthRank
FROM ranked;


-- Can we identify our top 3 most expensive services for each patient?
WITH Totalamoumtcharged as (
SELECT p.PatientID, p.fullname, t.ServiceProvided, SUM(t.AmountCharged) ServiceCharge
FROM Transactions t
RIGHT JOIN Patients p
ON t.PatientID = p.PatientID
GROUP BY PatientID, ServiceProvided
), ranks as (
SELECT fullname, ServiceProvided, ServiceCharge,
DENSE_RANK() OVER (PARTITION BY PatientID ORDER BY ServiceCharge DESC) as Rnk
FROM Totalamoumtcharged
)
SELECT fullname, ServiceProvided
FROM ranks
WHERE Rnk <= 3;



-- Who is our most frequently seen patient in terms of prescriptions, and what medications have they been prescribed?
WITH COUNT_PatientVisit as (
SELECT p.PatientID as PatientID, FullName, COUNT(PrescriptionID) PatientVisitTimes
FROM Patients p
JOIN AppointmentDetails a ON a.PatientID = p.PatientID
JOIN MedicationsPrescribed m ON a.AppointmentID = m.AppointmentID
group by p.PatientID
ORDER BY PatientVisitTimes  DESC LIMIT 1
)
SELECT c.PatientID, c.FullName, PatientVisitTimes, MedicationName
FROM COUNT_PatientVisit c
JOIN AppointmentDetails a ON a.PatientID = c.PatientID
JOIN MedicationsPrescribed m ON m.AppointmentID = a.AppointmentID;


-- How does our monthly revenue compare to the previous month?
WITH Total_Monthly_Revenue as (
SELECT CONCAT(YEAR(TransactionDate),'-',Month(TransactionDate)) "Year-Month" , SUM(AmountCharged) Monthly_Revenue
from Transactions
Group by CONCAT(YEAR(TransactionDate),'-',Month(TransactionDate))
ORDER by CONCAT(YEAR(TransactionDate),'-',Month(TransactionDate))
), base as (
SELECT *,
LAG(Monthly_Revenue) OVER (ORDER BY "Year-Month" ASC) Previous_Month_Revenue
FROM Total_Monthly_Revenue
)
SELECT *, Monthly_Revenue - Previous_Month_Revenue Diff_Month_on_Month
FROM base;
