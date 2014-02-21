/****** Object:  StoredProcedure bonus.SP020_ModifyStaffGroupItem    Script Date: 03/14/2012 20:58:29 ******/
if exists 
(
  select * 
  from sys.objects 
  where object_id = object_id('bonus.SP020_ModifyStaffGroupItem') 
  and type in ('P', 'PC')
)
drop procedure bonus.SP020_ModifyStaffGroupItem
go

set ansi_nulls on
go

set quoted_identifier on
go

-- ===================================================================
-- NAME:
--   bonus.SP020_ModifyStaffGroupItem
-- 
-- COPYRIGHT:
--   Skysource Technologies (c) 2011
-- 
-- DESCRIPTION:
--   update or insert staff group item
-- 
-- HISTORY:
--   2011-07-19 Livia Wu
--   File created.
--   2011-12-12 Tony Chi
--   Modify on update method
--   2012-03-09   Martin Ku
--   Remove usage on STAFF_GROUP_MAP for group item. We use STAFF_MAP instead.
-- ===================================================================

create procedure bonus.SP020_ModifyStaffGroupItem
  @STAFF_GROUP_ITEM_KEY int = null,
  @STAFF_GROUP_ITEM_NAME nvarchar(50) = null,
  @STAFF_GROUP_ID nvarchar(50) = null,
  @MONTH_START_DATE datetime = null,
  @UPDATE_BY_ID nvarchar(50) = null,
  @strActionType nvarchar(50) = null
as
  declare @intstaffGroupItemHistoryKey int = null
  declare @dtEffectiveStartDate datetime = null
  declare @intStaffMapKey int = null
  declare @strStaffGroupID nvarchar(50) = null
  declare @strBrandID nvarchar(50) = null
begin
  -- set NOCOUNT ON added to prevent extra result sets from interfering with select statements.
  set NOCOUNT on;

  -- get current history record's history key and effective start date
  select 
    @intstaffGroupItemHistoryKey = max(STAFF_GROUP_ITEM_HISTORY_KEY), 
    @strStaffGroupID = max(STAFF_GROUP_ID),
    @dtEffectiveStartDate = EFFECTIVE_START_DATE
  from bonus.STAFF_GROUP_ITEM_HISTORY
  where STAFF_GROUP_ITEM_KEY = @STAFF_GROUP_ITEM_KEY
  and EFFECTIVE_START_DATE <= @MONTH_START_DATE
  and EFFECTIVE_END_DATE > @MONTH_START_DATE
  group by EFFECTIVE_START_DATE

  if @strActionType = 'UPS'
  begin
    
    -- Insert new Staff Group Item  
    if @STAFF_GROUP_ITEM_KEY is not null and @STAFF_GROUP_ITEM_NAME is not null and @intstaffGroupItemHistoryKey is not null
    begin
    -- update
      update bonus.STAFF_GROUP_ITEM
      set 
        STAFF_GROUP_ITEM_NAME = @STAFF_GROUP_ITEM_NAME, 
        ACTIVE_FLAG = 'True',
        UPDATE_TIMESTAMP = getdate(),
        UPDATE_BY_ID = @UPDATE_BY_ID
      where STAFF_GROUP_ITEM_KEY = @STAFF_GROUP_ITEM_KEY
      
    --是否為當月
    --是
      if @dtEffectiveStartDate = @MONTH_START_DATE
      begin
        update bonus.STAFF_GROUP_ITEM_HISTORY
        set 
          STAFF_GROUP_ITEM_NAME = @STAFF_GROUP_ITEM_NAME, 
          UPDATE_TIMESTAMP = getdate(),
          UPDATE_BY_ID = @UPDATE_BY_ID
        where STAFF_GROUP_ITEM_HISTORY_KEY = @intstaffGroupItemHistoryKey
      end
    --否
      else
      begin
        update bonus.STAFF_GROUP_ITEM_HISTORY
        
        set 
          EFFECTIVE_END_DATE = @MONTH_START_DATE, 
          UPDATE_TIMESTAMP = getdate(),
          UPDATE_BY_ID = @UPDATE_BY_ID
        where STAFF_GROUP_ITEM_HISTORY_KEY = @intstaffGroupItemHistoryKey
        
        insert into bonus.STAFF_GROUP_ITEM_HISTORY
          (STAFF_GROUP_ITEM_KEY, STAFF_GROUP_ITEM_NAME, STAFF_GROUP_ID, EFFECTIVE_START_DATE, EFFECTIVE_END_DATE, CREATE_TIMESTAMP, CREATE_BY_ID)
        values (@STAFF_GROUP_ITEM_KEY, @STAFF_GROUP_ITEM_NAME, @strStaffGroupID, @MONTH_START_DATE, '9999-12-31', getdate(), @UPDATE_BY_ID)
      end
    end
    else if @STAFF_GROUP_ITEM_NAME is not null and @STAFF_GROUP_ID is not null and @intstaffGroupItemHistoryKey is null
    begin
      update bonus.STAFF_GROUP_ITEM
      set 
        STAFF_GROUP_ITEM_NAME = @STAFF_GROUP_ITEM_NAME, 
        STAFF_GROUP_ID = @STAFF_GROUP_ID,
        ACTIVE_FLAG = 'True',
        UPDATE_TIMESTAMP = getdate(),
        UPDATE_BY_ID = @UPDATE_BY_ID
      where STAFF_GROUP_ITEM_KEY = @STAFF_GROUP_ITEM_KEY
      if @@ROWCOUNT = 0
      -- Insert a new one if not existed
      begin
        insert into bonus.STAFF_GROUP_ITEM
          (STAFF_GROUP_ITEM_NAME, STAFF_GROUP_ID, ACTIVE_FLAG, CREATE_TIMESTAMP, CREATE_BY_ID)
        values (@STAFF_GROUP_ITEM_NAME, @STAFF_GROUP_ID, 'True', getdate(), @UPDATE_BY_ID)    
        insert into bonus.STAFF_GROUP_ITEM_HISTORY
          (STAFF_GROUP_ITEM_KEY, STAFF_GROUP_ITEM_NAME, STAFF_GROUP_ID, EFFECTIVE_START_DATE, EFFECTIVE_END_DATE, CREATE_TIMESTAMP, CREATE_BY_ID)
        values (SCOPE_IDENTITY(), @STAFF_GROUP_ITEM_NAME, @STAFF_GROUP_ID, @MONTH_START_DATE, '9999-12-31', getdate(), @UPDATE_BY_ID) 		
      end
      else
      begin
        insert into bonus.STAFF_GROUP_ITEM_HISTORY
          (STAFF_GROUP_ITEM_KEY, STAFF_GROUP_ITEM_NAME, STAFF_GROUP_ID, EFFECTIVE_START_DATE, EFFECTIVE_END_DATE, CREATE_TIMESTAMP, CREATE_BY_ID)
        values (@STAFF_GROUP_ITEM_KEY, @STAFF_GROUP_ITEM_NAME, @STAFF_GROUP_ID, @MONTH_START_DATE, '9999-12-31', getdate(), @UPDATE_BY_ID)        
      end
    end
  end   
  else if @strActionType = 'DEL'
  begin
  --刪除小組負責人員 
    --選取小組負責人員
    declare staffMapKeycursor cursor for
    select STAFF_MAP_KEY from bonus.STAFF_MAP
    where STAFF_GROUP_ITEM_KEY = @STAFF_GROUP_ITEM_KEY
    and STAFF_MAP_TYPE_ID = 'SM002'
    and ACTIVE_FLAG = 'True'

    --開啟資料庫cursor
    open staffMapKeycursor
    fetch next from staffMapKeycursor into @intStaffMapKey
    while @@FETCH_STATUS = 0
    begin
      exec bonus.SP010_ModifyStaffMap
      @STAFF_MAP_KEY = @intStaffMapKey,
      @MONTH_START_DATE = @MONTH_START_DATE,
      @UPDATE_BY_ID = @UPDATE_BY_ID,
      @strActionType = 'DEL'
      fetch next from staffMapKeycursor into @intStaffMapKey
    end
    close staffMapKeycursor
    deallocate staffMapKeycursor
    
  --刪除小組負責品牌
    --選取小組所屬品牌
    declare staffGroupMapKeycursor cursor for
    select STAFF_GROUP_ID, BRAND_ID from bonus.STAFF_GROUP_MAP
    where STAFF_GROUP_ITEM_KEY = @STAFF_GROUP_ITEM_KEY
    and STAFF_GROUP_MAP_TYPE_ID = 'SGM002'
    and ACTIVE_FLAG = 'True'

    --開啟資料庫cursor
    open staffGroupMapKeycursor
    fetch next from staffGroupMapKeycursor into @strStaffGroupID, @strBrandID
    while @@FETCH_STATUS = 0
    begin
      exec bonus.SP005_ModifyStaffGroupMap
      @STAFF_GROUP_ID = @strStaffGroupID,
      @BRAND_ID = @strBrandID,
      @STAFF_GROUP_MAP_TYPE_ID = 'SGM002',
      @STAFF_GROUP_ITEM_KEY = null,
      @MONTH_START_DATE = @MONTH_START_DATE,
      @UPDATE_BY_ID = @UPDATE_BY_ID,
      @strActionType = 'UPS'
      fetch next from staffGroupMapKeycursor into @strStaffGroupID, @strBrandID
    end
    close staffGroupMapKeycursor
    deallocate staffGroupMapKeycursor
    
    if @dtEffectiveStartDate = @MONTH_START_DATE
    begin    
      delete from bonus.STAFF_GROUP_ITEM_HISTORY
      where STAFF_GROUP_ITEM_KEY = @STAFF_GROUP_ITEM_KEY
      and EFFECTIVE_START_DATE = @MONTH_START_DATE              
    
      -- Type 2, get remaining inactivated historical data

      select @intstaffGroupItemHistoryKey = max(STAFF_GROUP_ITEM_HISTORY_KEY)
      from bonus.STAFF_GROUP_ITEM_HISTORY
      where STAFF_GROUP_ITEM_KEY = @STAFF_GROUP_ITEM_KEY
      
      -- Type 3, no inactivated historical data
      -- Type 2, historical data exist, reset current record
      if @intstaffGroupItemHistoryKey is null
      begin
        delete from bonus.STAFF_GROUP_ITEM
        where STAFF_GROUP_ITEM_KEY = @STAFF_GROUP_ITEM_KEY        
      end      
      else
      begin
        update bonus.STAFF_GROUP_ITEM
        set
          STAFF_GROUP_ITEM_NAME = t1.STAFF_GROUP_ITEM_NAME,
          STAFF_GROUP_ID = t1.STAFF_GROUP_ID,
          ACTIVE_FLAG = 'False',
          UPDATE_TIMESTAMP = getdate(),
          UPDATE_BY_ID = @UPDATE_BY_ID
        from
        (
          select
            STAFF_GROUP_ITEM_NAME,
            STAFF_GROUP_ID
          from bonus.STAFF_GROUP_ITEM_HISTORY
          where STAFF_GROUP_ITEM_HISTORY_KEY = @intstaffGroupItemHistoryKey
        ) t1
        where STAFF_GROUP_ITEM_KEY = @STAFF_GROUP_ITEM_KEY
      end      
    end
    -- Type 1, update exiting records in current and history table for logical delete
    else
    begin
      update bonus.STAFF_GROUP_ITEM
      set
        ACTIVE_FLAG = 'False',
        UPDATE_TIMESTAMP = getdate(),
        UPDATE_BY_ID = @UPDATE_BY_ID
      where STAFF_GROUP_ITEM_KEY = @STAFF_GROUP_ITEM_KEY
      
      update bonus.STAFF_GROUP_ITEM_HISTORY
      set
        EFFECTIVE_END_DATE = @MONTH_START_DATE,
        UPDATE_TIMESTAMP = getdate(),
        UPDATE_BY_ID = @UPDATE_BY_ID
      where STAFF_GROUP_ITEM_KEY = @STAFF_GROUP_ITEM_KEY
      and EFFECTIVE_START_DATE <= @MONTH_START_DATE
      and EFFECTIVE_END_DATE > @MONTH_START_DATE
    end
  end
end

go