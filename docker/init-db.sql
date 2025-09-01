-- Create databases for Builder and Target containers
CREATE DATABASE allspark_builder;
CREATE DATABASE allspark_target;

-- Grant all privileges to postgres user
GRANT ALL PRIVILEGES ON DATABASE allspark_builder TO postgres;
GRANT ALL PRIVILEGES ON DATABASE allspark_target TO postgres;