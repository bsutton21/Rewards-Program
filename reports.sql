-- Blake Sutton

/* The company is looking to introduce a rewards program
/  and is trying to figure out the best way to implement it.  
/  They need a report that lists the total expenditure and total number of rentals for each customer.  
/  They would prefer to have this sorted/ordered in descending order by expenditure.  
/  A more detailed report/table will include customer email and address information, as well, 
/  so that they can be contacted once the rewards program is set up.*/


-- creates a procedure to automatically generate the reports

CREATE OR REPLACE PROCEDURE create_reports()
LANGUAGE PLPGSQL
AS $$
BEGIN

	-- creates the detailed_report table to store the detailed report if the table doesn't already exists
	CREATE TABLE IF NOT EXISTS detailed_report (
		customer_id INT,
		first_name VARCHAR(45),
		last_name VARCHAR(45),
		email VARCHAR(50),
		address VARCHAR(50),
		address2 VARCHAR(50),
		city VARCHAR(50),
		postal_code VARCHAR(10),
		phone VARCHAR(20),
		active_status TEXT,
		payment_id INT,
		amount numeric(5,2),
		payment_date TIMESTAMP
	);

	-- deletes all data from detailed_report table
	TRUNCATE detailed_report;

	-- populates detailed_report with data from a query joining the customer, address and payment tables
	-- uses CASE to change activebool to the values 'Active' and 'Inactive' to remove confusion for users
	INSERT INTO detailed_report
		SELECT 
			cu.customer_id, 
			cu.first_name, 
			cu.last_name, 
			cu.email, 
			ad.address, 
			ad.address2, 
			(SELECT city FROM PUBLIC.CITY WHERE city_id = ad.city_id), 
			ad.postal_code, 
			ad.phone, 
			CASE cu.activebool
				WHEN true THEN 'Active'
				WHEN false THEN 'Inactive'
			END active_status, 
			pay.payment_id,
			pay.amount, 
			pay.payment_date 
		FROM 
			public.payment pay
		JOIN 
			public.customer cu ON pay.customer_id = cu.customer_id
		JOIN 
			public.address ad ON ad.address_id = cu.address_id
		ORDER BY customer_id
	;

	-- creates the summary_report table to store the summary report if the table doesn't already exists
	CREATE TABLE IF NOT EXISTS summary_report (
		customer_id INT,
		amount_spent numeric(5,2),
		rental_count INT
	);

	-- deletes all data from summary_report table
	TRUNCATE summary_report;

	-- populates the summary_report with specific data from the detailed_report 
	INSERT INTO summary_report
		SELECT
			customer_id,
			sum(amount) as dollars,
			count(amount) as orders
		FROM
			detailed_report
		GROUP BY customer_id
		ORDER BY dollars desc
	;

END;$$;

-- creates the reports by calling the function then committing manually to create the tables and initialize the data
-- users can simply type the two lines below to manually refresh these tables at any time
call create_reports();
COMMIT;

-- creates trigger function to refresh the summary report whenever the detailed report is updated
CREATE OR REPLACE FUNCTION refresh_summary()
	RETURNS TRIGGER
	LANGUAGE PLPGSQL
AS $$
BEGIN
	TRUNCATE summary_report;
	INSERT INTO summary_report
		SELECT
			customer_id,
			sum(amount),
			count(amount)	
		FROM
			detailed_report
		GROUP BY customer_id
		ORDER BY sum desc
	;
END;$$;

-- creates trigger event to call the trigger function
CREATE TRIGGER summary_trigger
	AFTER UPDATE
	ON detailed_report
	FOR EACH ROW
		EXECUTE PROCEDURE refresh_summary();
