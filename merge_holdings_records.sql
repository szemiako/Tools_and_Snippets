USE PROD
GO

BEGIN TRAN

DECLARE
	@commit BIT,
	@ErrorNumber INT,
	@ErrorSeverity INT,
	@ErrorState INT,
	@ErrorLine INT,
	@ErrorProcedure VARCHAR(100),
	@ErrorMessage VARCHAR(500),
	@Error INT;

SET @commit = 0

BEGIN TRY

	DECLARE @to_merge TABLE ( oldGUID UNIQUEIDENTIFIER, newGUID UNIQUEIDENTIFIER )
	DECLARE @oldGUID UNIQUEIDENTIFIER, @newGUID UNIQUEIDENTIFIER
	DECLARE @counter INT = 0

	INSERT INTO @to_merge (oldGUID, newGUID) VALUES (N'a0ea9590-31ce-46e3-a6ed-b6915378cafc', N'cbc1ed97-1f41-4cdf-8009-a9f30b427ee3')
	
	SELECT COUNT(*) [Rows to Update] FROM @to_merge

	DECLARE map_cursor CURSOR FOR
		SELECT oldGUID, newGUID
		FROM @to_merge

	OPEN map_cursor

	FETCH NEXT FROM map_cursor
	INTO @oldGUID, @newGUID

	WHILE @@FETCH_STATUS = 0
		BEGIN

			UPDATE [Trades] SET [GUID]=@newGUID WHERE [GUID]=@oldGUID

			UPDATE [DailyProcess] SET [GUID]=@newGUID WHERE [Balance]<>0 AND [GUID]=@oldGUID

			DELETE FROM [DailyProcess] WHERE [Balance]=0 AND [GUID]=@oldGUID

			UPDATE [Archive] SET [GUID]=@newGUID WHERE [GUID]=@oldGUID

			DELETE FROM [Holdings] WHERE [GUID]=@oldGUID

			SET @counter += 1

			FETCH NEXT FROM map_cursor
			INTO @oldGUID, @newGUID
		END

	SELECT @counter [Records Updated]

	CLOSE map_cursor
	DEALLOCATE map_cursor

END TRY

BEGIN CATCH
    SELECT 
        @ErrorNumber = ERROR_NUMBER(),
        @ErrorSeverity = ERROR_SEVERITY(),
        @ErrorState = ERROR_STATE(),
        @ErrorLine = ERROR_LINE(),
        @ErrorProcedure = ERROR_PROCEDURE(),
        @Error = @@ERROR; 

    SELECT @ErrorMessage = N'Error encountered during query evaluation: %d, Level %d, State %d, Procedure %s, Line %d, ' + 'Issue: '+ ERROR_MESSAGE();
    PRINT @ErrorMessage;
    RAISERROR (@ErrorMessage, @ErrorSeverity, 1, @ErrorNumber, @ErrorSeverity, @ErrorState, @ErrorProcedure, @ErrorLine);
    ROLLBACK TRAN;

END CATCH



IF @commit = 0
	BEGIN
		ROLLBACK TRAN
		SELECT 'DID NOT COMMIT' [Result]
	END
ELSE
	BEGIN
		COMMIT TRAN
		SELECT 'COMMITTED' [Result]
	END