/****** Object:  StoredProcedure [bonus].[SP020_ModifyStaffGroupItem]    Script Date: 03/14/2012 20:58:29 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ===================================================================
-- NAME:
--   bonus.SP020_ModifyStaffGroupItem
-- 
-- COPYRIGHT:
--   Skysource Technologies (c) 2011
-- 
-- DESCRIPTION:
--   Update or insert staff group item
-- 
-- HISTORY:
--   2011-07-19 Livia Wu
--   File created.
--   2011-12-12 Tony Chui
--   Modify on Update method
--   2012-03-09   Martin Ku
--   Remove usage on STAFF_GROUP_MAP for group item. We use STAFF_MAP instead.
-- ===================================================================

CREATE PROCEDURE [bonus].[SP020_ModifyStaffGroupItem]
  @STAFF_GROUP_ITEM_KEY int = null,
  @STAFF_GROUP_ITEM_NAME nvarchar(50) = null,
  @STAFF_GROUP_ID nvarchar(50) = null,
  @MONTH_START_DATE datetime = null,
  @UPDATE_BY_ID nvarchar(50) = null,
  @strActionType nvarchar(50) = null
AS
  DECLARE @intstaffGroupItemKey nvarchar(50) = null
  DECLARE @intstaffGroupItemHistoryKey int = null
  DECLARE @dtEffectiveStartDate datetime = null
  DECLARE @intstaffGroupMapHistoryKey int = null
BEGIN
  -- SET NOCOUNT ON added to prevent extra result sets from interfering with SELECT statements.
  SET NOCOUNT ON;

  -- get current histroy record's history key and effective start date
  SELECT @intstaffGroupItemHistoryKey = MAX(STAFF_GROUP_ITEM_HISTORY_KEY), @dtEffectiveStartDate = EFFECTIVE_START_DATE
  FROM bonus.STAFF_GROUP_ITEM_HISTORY
  WHERE STAFF_GROUP_ITEM_KEY = @STAFF_GROUP_ITEM_KEY
  AND EFFECTIVE_START_DATE <= @MONTH_START_DATE
  AND EFFECTIVE_END_DATE > @MONTH_START_DATE
  GROUP BY EFFECTIVE_START_DATE

  IF @strActionType = 'UPS'
  BEGIN
    IF @STAFF_GROUP_ITEM_KEY IS NULL
    BEGIN
      SELECT @intstaffGroupItemKey = STAFF_GROUP_ITEM_KEY 
      FROM bonus.STAFF_GROUP_ITEM 
      WHERE STAFF_GROUP_ITEM_NAME = @STAFF_GROUP_ITEM_NAME
    END
    ELSE 
    BEGIN
      SELECT @intstaffGroupItemKey = @STAFF_GROUP_ITEM_KEY 
    END
    
    -- Insert new Staff Class    
    IF @intstaffGroupItemKey IS NOT NULL AND @STAFF_GROUP_ITEM_NAME IS NOT NULL AND @intstaffGroupItemHistoryKey IS NOT NULL
    BEGIN
    -- UPDATE    

      UPDATE bonus.STAFF_GROUP_ITEM
      SET 
        STAFF_GROUP_ITEM_NAME = @STAFF_GROUP_ITEM_NAME, 
        ACTIVE_FLAG = 'True',
        UPDATE_TIMESTAMP = GETDATE(),
        UPDATE_BY_ID = @UPDATE_BY_ID
      WHERE STAFF_GROUP_ITEM_KEY = @STAFF_GROUP_ITEM_KEY
      

    --是否為當月
    --是
      IF @dtEffectiveStartDate = @MONTH_START_DATE
      BEGIN
        UPDATE bonus.STAFF_GROUP_ITEM_HISTORY
        SET 
          STAFF_GROUP_ITEM_NAME = @STAFF_GROUP_ITEM_NAME, 
          UPDATE_TIMESTAMP = GETDATE(),
          UPDATE_BY_ID = @UPDATE_BY_ID
        WHERE STAFF_GROUP_ITEM_HISTORY_KEY = @intstaffGroupItemHistoryKey
      END
      ELSE IF @dtEffectiveStartDate <> @MONTH_START_DATE
      BEGIN
        UPDATE bonus.STAFF_GROUP_ITEM_HISTORY
        SET 
          EFFECTIVE_END_DATE = @MONTH_START_DATE, 
          UPDATE_TIMESTAMP = GETDATE(),
          UPDATE_BY_ID = @UPDATE_BY_ID
        WHERE STAFF_GROUP_ITEM_HISTORY_KEY = @intstaffGroupItemHistoryKey
        
        INSERT INTO bonus.STAFF_GROUP_ITEM_HISTORY
          (STAFF_GROUP_ITEM_KEY, STAFF_GROUP_ITEM_NAME, STAFF_GROUP_ID, EFFECTIVE_START_DATE, EFFECTIVE_END_DATE, CREATE_TIMESTAMP, CREATE_BY_ID)
        VALUES (@intstaffGroupItemKey, @STAFF_GROUP_ITEM_NAME, @STAFF_GROUP_ID, @MONTH_START_DATE, '9999-12-31', GETDATE(), @UPDATE_BY_ID)      
      END
    END
    ELSE IF @STAFF_GROUP_ITEM_NAME IS NOT NULL AND @intstaffGroupItemHistoryKey IS NULL
    BEGIN

      INSERT INTO bonus.STAFF_GROUP_ITEM
        (STAFF_GROUP_ITEM_NAME, STAFF_GROUP_ID, ACTIVE_FLAG, CREATE_TIMESTAMP, CREATE_BY_ID)
      VALUES (@STAFF_GROUP_ITEM_NAME, @STAFF_GROUP_ID, 'True', GETDATE(), @UPDATE_BY_ID)       
        
      INSERT INTO bonus.STAFF_GROUP_ITEM_HISTORY
        (STAFF_GROUP_ITEM_KEY, STAFF_GROUP_ITEM_NAME, STAFF_GROUP_ID, EFFECTIVE_START_DATE, EFFECTIVE_END_DATE, CREATE_TIMESTAMP, CREATE_BY_ID)
      VALUES (SCOPE_IDENTITY(), @STAFF_GROUP_ITEM_NAME, @STAFF_GROUP_ID, @MONTH_START_DATE, '9999-12-31', GETDATE(), @UPDATE_BY_ID)        
    END
  END    
  ELSE IF @strActionType = 'DEL'
  BEGIN
    IF @dtEffectiveStartDate = @MONTH_START_DATE
    BEGIN    
      --刪除小組負責人員
      BEGIN
        DELETE bonus.STAFF_MAP_HISTORY
        WHERE STAFF_GROUP_ITEM_KEY = @STAFF_GROUP_ITEM_KEY
        AND STAFF_MAP_TYPE_ID = 'SM002' --營業職員暨店櫃長負責小組
        AND EFFECTIVE_START_DATE = @MONTH_START_DATE

        DELETE bonus.STAFF_MAP
        WHERE STAFF_GROUP_ITEM_KEY = @STAFF_GROUP_ITEM_KEY
        AND STAFF_MAP_TYPE_ID = 'SM002'
        AND ACTIVE_FLAG = 'True'
      END      
    
      DELETE FROM bonus.STAFF_GROUP_ITEM_HISTORY
      WHERE STAFF_GROUP_ITEM_KEY = @STAFF_GROUP_ITEM_KEY
      AND EFFECTIVE_START_DATE = @MONTH_START_DATE              
    
      -- Type 2, get remaining inactivated historical data

      SELECT @intstaffGroupItemHistoryKey = MAX(STAFF_GROUP_ITEM_HISTORY_KEY)
      FROM bonus.STAFF_GROUP_ITEM_HISTORY
      WHERE STAFF_GROUP_ITEM_KEY = @STAFF_GROUP_ITEM_KEY
      
      -- Type 3, no inactivated historical data
      -- Type 2, historical data exist, reset current record
      IF @intstaffGroupItemHistoryKey IS NULL
      BEGIN
        DELETE FROM bonus.STAFF_GROUP_ITEM
        WHERE STAFF_GROUP_ITEM_KEY = @STAFF_GROUP_ITEM_KEY        
      END      
      ELSE
      BEGIN
        UPDATE bonus.STAFF_GROUP_ITEM
        SET
          STAFF_GROUP_ITEM_NAME = 
          (
            SELECT STAFF_GROUP_ITEM_NAME 
            FROM bonus.STAFF_GROUP_ITEM_HISTORY
            WHERE STAFF_GROUP_ITEM_HISTORY_KEY = @intstaffGroupItemHistoryKey
          ),
          ACTIVE_FLAG = 'False',
          UPDATE_TIMESTAMP = GETDATE(),
          UPDATE_BY_ID = @UPDATE_BY_ID
        WHERE STAFF_GROUP_ITEM_KEY = @STAFF_GROUP_ITEM_KEY
      END      
    END
    -- Type 1, update exiting records in current and history table for logical delete
    ELSE
    BEGIN
      --刪除小組負責人員
      BEGIN
        UPDATE bonus.STAFF_MAP
        SET
        ACTIVE_FLAG = 'False'
        WHERE STAFF_GROUP_ITEM_KEY = @STAFF_GROUP_ITEM_KEY
        AND STAFF_MAP_TYPE_ID = 'SM002'

        UPDATE bonus.STAFF_MAP_HISTORY
        SET
        EFFECTIVE_END_DATE = @MONTH_START_DATE,
        UPDATE_TIMESTAMP = GETDATE(),
        UPDATE_BY_ID = @UPDATE_BY_ID
        WHERE STAFF_GROUP_ITEM_KEY = @STAFF_GROUP_ITEM_KEY
        AND STAFF_MAP_TYPE_ID = 'SM002'
        AND EFFECTIVE_START_DATE <= @MONTH_START_DATE
        AND EFFECTIVE_END_DATE > @MONTH_START_DATE
      END     
      
      BEGIN
        UPDATE bonus.STAFF_GROUP_ITEM
        SET
          ACTIVE_FLAG = 'False',
          UPDATE_TIMESTAMP = GETDATE(),
          UPDATE_BY_ID = @UPDATE_BY_ID
        WHERE STAFF_GROUP_ITEM_KEY = @STAFF_GROUP_ITEM_KEY
      
        UPDATE bonus.STAFF_GROUP_ITEM_HISTORY
        SET
          EFFECTIVE_END_DATE = @MONTH_START_DATE,
          UPDATE_TIMESTAMP = GETDATE(),
          UPDATE_BY_ID = @UPDATE_BY_ID
        WHERE STAFF_GROUP_ITEM_KEY = @STAFF_GROUP_ITEM_KEY
        AND EFFECTIVE_START_DATE <= @MONTH_START_DATE
        AND EFFECTIVE_END_DATE > @MONTH_START_DATE
      END
    END
  END
END

GO


