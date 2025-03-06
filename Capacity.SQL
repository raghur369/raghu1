USE msdb

SET NOCOUNT ON;

DECLARE @Database_name nvarchar(200),
@DATASIZE DECIMAL(15,2),
@Current_DATADRIVE_MB DECIMAL(15,2),
@Requirement_DATADRIVE_MB DECIMAL(15,2)

DECLARE @DBSizes TABLE
( Servername nvarchar(200)  NULL,
Databasename nvarchar(200)  NULL,
Percentile numeric(10,5)  NULL,
DATASIZE DECIMAL(15,2),
ESTIMATEDSIZE DECIMAL(15,2)
);


DECLARE CAPACITY_Planning CURSOR FOR
select [name] from master.sys.databases
where [name] not in ('master','msdb','tempdb','model','DBA')


OPEN Capacity_Planning

FETCH NEXT FROM CAPACITY_Planning

INTO @Database_name

WHILE @@FETCH_STATUS=0

BEGIN

DECLARE @PERCENTILE numeric(10,5)

CREATE TABLE #Metric111(
name nvarchar(200),
month_num int,
backup_size numeric(10,5)
)

INSERT INTO #Metric111([name],month_num,backup_size)
SELECT 
[database_name] AS "Database",
DATEPART(month,[backup_start_date]) AS "Month",
(AVG([backup_size]/1024/1024/1024)) AS "Backup Size GB"

FROM msdb.dbo.backupset
WHERE [database_name]=@Database_name
AND [type]='D'
GROUP BY [database_name],DATEPART(mm,[backup_start_date])


SET @percentile = (select ((max(backup_size)-min(backup_size))*(100))/(max(backup_size))  from #Metric111)

SET @DATASIZE =(select 

--- d.name as DatabaseName,
CAST(SUM((a.size/128.0)) AS DECIMAL(15,2))  AS  [DataSize_MB]

from [sys].[master_files] a
inner join sys.databases d
on a.database_id=d.database_id
where a.[type_desc]='ROWS'  and  d.name=@Database_name
GROUP BY d.name
)

--- select * from #metric111
--- order by month_num


insert into @DBSizes(Servername,Databasename,Percentile,DATASIZE,ESTIMATEDSIZE)

---- Select @@servername as SERVERNAME , @Database_name AS DNAME , @percentile as PERCENTILE


Select @@servername as SERVERNAME , @Database_name AS DNAME , @percentile AS PERCENTILE , @DATASIZE AS DATASIZE , (@DATASIZE) + (@DATASIZE*(@percentile/100)) + (@DATASIZE*30/100)


FETCH NEXT FROM CAPACITY_Planning

INTO @Database_name

DROP TABLE #Metric111

END

CLOSE Capacity_Planning
DEALLOCATE Capacity_Planning


----- Select Servername , Databasename , Percentile as GrowthPercent , DATASIZE as DataSize_MB , ESTIMATEDSIZE as EstimatedSize_MB from @DBSizes

SET @Current_DATADRIVE_MB=(Select SUM(DataSize) AS Current_DATADRIVE_MB from @DBSizes)

SET @Requirement_DATADRIVE_MB = (Select SUM(ESTIMATEDSIZE) as Requirement_DATADRIVE_MB from @DBSizes)


Select Servername,Databasename,Percentile as GrowthPercent , DATASIZE as DataSize_MB , ESTIMATEDSIZE as EstimatedSize_MB from @DBSizes

Select @@SERVERNAME as ServerName , @Current_DATADRIVE_MB , 
@Requirement_DATADRIVE_MB as Requirement_DATADRIVE_MB


SELECT distinct(volume_mount_point),
total_bytes/1048576/1024 as Size_in_GB,
available_bytes/1048576/1024 as Free_in_GB,
(select ((available_bytes/1048576*1.0)/(total_bytes/1048576*1.0)*100)) as FREEPercentage

FROM sys.master_files AS f CROSS APPLY
sys.dm_os_volume_stats(f.database_id,f.file_id)
where f.type_desc='ROWS'
GROUP BY volume_mount_point , total_bytes/1048576,available_bytes/1048576
order by 1


select b.name as DatabaseName , a.physical_name as PhysicalLocation from sys.master_files a inner join sys.databases b
on a.database_id=b.database_id
where a.database_id>4 and a.type_desc='ROWS'

























