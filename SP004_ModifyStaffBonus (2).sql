/****** Object:  StoredProcedure [bonus].[SP004_ModifyStaffBonus]    Script Date: 03/14/2012 20:56:31 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ===================================================================
-- NAME:
--   bonus.SP004_ModifyStaffBonus
-- 
-- COPYRIGHT:
--   Skysource Technologies (c) 2011
-- 
-- DESCRIPTION:
--   Modify staff bonus amount, include insert delete and update.
-- 
-- HISTORY:
--   2011-04-30  Tony Chi
--   File created.
-- ===================================================================

CREATE PROCEDURE [bonus].[SP004_ModifyStaffBonus]
  @SITE_ID nvarchar(50) = null,
  @STAFF_ID nvarchar(50) = null,
  @MONTH_START_DATE datetime = null,
  @BONUS_AMOUNT nvarchar(50) = null,
  @UPDATE_BY_ID nvarchar(50) = null,
  @STAFF_BONUS_KEY nvarchar(50) = null,
  @REMARK_SOURCE nvarchar(50) = null,
  @REMARK_CONTENT nvarchar(255) = null,
  @ACTION_TYPE nvarchar(10) = null,
  @STAFF_BONUS_CATEGORY_ID nvarchar(50) = null
AS
  DECLARE @strStaffInsertBonusCategoryID nvarchar(50) = null
  DECLARE @intStaffBonusKey int = null
  DECLARE @dtRecordInsertDate datetime = GETDATE()
  DECLARE @dtMonthStartDate datetime = null
  
BEGIN
  -- SET NOCOUNT ON added to prevent extra result sets from interfering with SELECT statements.
  SET NOCOUNT OFF;

  IF @ACTION_TYPE = 'UPS'
  BEGIN
    IF @STAFF_BONUS_KEY IS NOT NULL
    BEGIN
      SELECT @strStaffInsertBonusCategoryID = sb.BONUS_CATEGORY_ID
      FROM bonus.STAFF_BONUS sb
      INNER JOIN bonus.BONUS_CATEGORY bc ON sb.BONUS_CATEGORY_ID = bc.BONUS_CATEGORY_ID
      WHERE STAFF_BONUS_KEY = @STAFF_BONUS_KEY 

      IF @strStaffInsertBonusCategoryID = @STAFF_BONUS_CATEGORY_ID
      BEGIN
        -- 如果是調整獎金TYPE 必定是修改
     
        -- UPDATE A RECORD
        SELECT @dtMonthStartDate = CONVERT(NVARCHAR(10), MONTH_START_DATE, 120) 
        FROM bonus.STAFF_BONUS
        WHERE STAFF_BONUS_KEY = @STAFF_BONUS_KEY 
     
        -- CHECK CONTAIN, BONUS AMOUNT, MONTH START DATE IS VALID
        IF @REMARK_CONTENT IS NOT NULL AND @BONUS_AMOUNT IS NOT NULL AND @dtMonthStartDate = @MONTH_START_DATE 
        BEGIN
          UPDATE bonus.REMARK SET REMARK_CONTENT = @REMARK_CONTENT, UPDATE_TIMESTAMP = GETDATE(), UPDATE_BY_ID = @UPDATE_BY_ID
          WHERE REMARK_RECORD_NO = @STAFF_BONUS_KEY
        
          UPDATE bonus.STAFF_BONUS SET BONUS_AMOUNT = @BONUS_AMOUNT, UPDATE_TIMESTAMP = GETDATE(), UPDATE_BY_ID = @UPDATE_BY_ID
          WHERE STAFF_BONUS_KEY = @STAFF_BONUS_KEY
        END -- @REMARK_CONTENT IS NOT NULL AND @BONUS_AMOUNT IS NOT NULL AND @dtMonthStartDate = @MONTH_START_DATE
      END 
      ELSE
      BEGIN
        -- 不同獎金格式是新增一筆調整獎金
        -- INSERT A NEW RECORD      
        IF @REMARK_CONTENT IS NOT NULL AND @BONUS_AMOUNT IS NOT NULL
        BEGIN

          INSERT INTO bonus.STAFF_BONUS (SITE_ID, STAFF_ID, MONTH_START_DATE, BONUS_REFER_KEY, BONUS_CATEGORY_ID, BONUS_AMOUNT, CREATE_TIMESTAMP, CREATE_BY_ID)
          VALUES (@SITE_ID, @STAFF_ID, @MONTH_START_DATE, @strStaffInsertBonusCategoryID, @STAFF_BONUS_CATEGORY_ID, @BONUS_AMOUNT, @dtRecordInsertDate, @UPDATE_BY_ID)

          SELECT @intStaffBonusKey = STAFF_BONUS_KEY
          FROM bonus.STAFF_BONUS
          WHERE STAFF_ID = @STAFF_ID AND MONTH_START_DATE = @MONTH_START_DATE 
          AND BONUS_CATEGORY_ID = @STAFF_BONUS_CATEGORY_ID AND CREATE_TIMESTAMP = @dtRecordInsertDate
      
          INSERT INTO bonus.REMARK (REMARK_SOURCE, REMARK_RECORD_NO, REMARK_CONTENT, CREATE_TIMESTAMP, CREATE_BY_ID)
          VALUES (@REMARK_SOURCE, @intStaffBonusKey, @REMARK_CONTENT,  GETDATE(), @UPDATE_BY_ID)

        END -- @REMARK_CONTENT IS NOT NULL AND @BONUS_AMOUNT IS NOT NULL
      END 
    END -- @STAFF_BONUS_KEY IS NOT NULL
    ELSE
    BEGIN
      -- INSERT A NEW RECORD NO REFER KEY
      IF @REMARK_CONTENT IS NOT NULL AND @BONUS_AMOUNT IS NOT NULL
      BEGIN
      
        INSERT INTO bonus.STAFF_BONUS (SITE_ID, STAFF_ID, MONTH_START_DATE, BONUS_CATEGORY_ID, BONUS_AMOUNT, CREATE_TIMESTAMP, CREATE_BY_ID)
        VALUES (@SITE_ID, @STAFF_ID, @MONTH_START_DATE, @STAFF_BONUS_CATEGORY_ID, @BONUS_AMOUNT, @dtRecordInsertDate, @UPDATE_BY_ID)      

        SELECT @intStaffBonusKey = STAFF_BONUS_KEY
        FROM bonus.STAFF_BONUS
        WHERE STAFF_ID = @STAFF_ID AND MONTH_START_DATE = @MONTH_START_DATE 
        AND BONUS_CATEGORY_ID = @STAFF_BONUS_CATEGORY_ID AND CREATE_TIMESTAMP = @dtRecordInsertDate
      
        INSERT INTO bonus.REMARK (REMARK_SOURCE, REMARK_RECORD_NO, REMARK_CONTENT, CREATE_TIMESTAMP, CREATE_BY_ID)
        VALUES (@REMARK_SOURCE, @intStaffBonusKey, @REMARK_CONTENT,  GETDATE(), @UPDATE_BY_ID)

      END -- @REMARK_CONTENT IS NOT NULL AND @BONUS_AMOUNT IS NOT NULL
    END -- @STAFF_BONUS_KEY IS NOT NULL
  END
  ELSE IF @ACTION_TYPE = 'DEL'
  BEGIN
    IF @STAFF_BONUS_KEY IS NOT NULL
    BEGIN
      DELETE FROM bonus.REMARK
      WHERE REMARK_RECORD_NO = @STAFF_BONUS_KEY
      
      DELETE FROM bonus.STAFF_BONUS
      WHERE STAFF_BONUS_KEY = @STAFF_BONUS_KEY
    END -- @STAFF_BONUS_KEY IS NOT NULL
  END -- @ACTION_TYPE = 'DEL'
END

GO


