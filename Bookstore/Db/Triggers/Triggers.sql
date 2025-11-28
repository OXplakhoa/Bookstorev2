USE BookstoreDb;
GO

-- =============================================
-- TRIGGER 1: tr_Products_SetCreatedAt
-- Loại: AFTER INSERT
-- Mục đích: Tự động gán thời gian tạo sản phẩm
-- =============================================
IF OBJECT_ID('dbo.tr_Products_SetCreatedAt', 'TR') IS NOT NULL
    DROP TRIGGER dbo.tr_Products_SetCreatedAt;
GO

CREATE TRIGGER tr_Products_SetCreatedAt
ON dbo.Products
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Cập nhật CreatedAt cho sản phẩm mới nếu chưa có giá trị
    UPDATE p
    SET p.CreatedAt = GETUTCDATE()
    FROM dbo.Products p
    INNER JOIN inserted i ON p.ProductId = i.ProductId
    WHERE p.CreatedAt IS NULL;
END
GO

PRINT N'✓ Trigger 1: tr_Products_SetCreatedAt đã tạo thành công.';
GO

-- =============================================
-- TRIGGER 2: tr_Orders_SetCreatedAt
-- Loại: AFTER INSERT
-- Mục đích: Tự động gán thời gian tạo đơn hàng
-- =============================================
IF OBJECT_ID('dbo.tr_Orders_SetCreatedAt', 'TR') IS NOT NULL
    DROP TRIGGER dbo.tr_Orders_SetCreatedAt;
GO

CREATE TRIGGER tr_Orders_SetCreatedAt
ON dbo.Orders
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Gán thời gian hiện tại cho đơn hàng mới
    UPDATE o
    SET o.OrderDate = GETUTCDATE()
    FROM dbo.Orders o
    INNER JOIN inserted i ON o.OrderId = i.OrderId
    WHERE o.OrderDate IS NULL;
END
GO

PRINT N'✓ Trigger 2: tr_Orders_SetCreatedAt đã tạo thành công.';
GO

-- =============================================
-- TRIGGER 3: tr_Users_UpdateTimestamp
-- Loại: AFTER UPDATE
-- Mục đích: Tự động cập nhật thời gian khi user thay đổi thông tin
-- =============================================
IF OBJECT_ID('dbo.tr_Users_UpdateTimestamp', 'TR') IS NOT NULL
    DROP TRIGGER dbo.tr_Users_UpdateTimestamp;
GO

CREATE TRIGGER tr_Users_UpdateTimestamp
ON dbo.AspNetUsers
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Cập nhật UpdatedAt mỗi khi user sửa thông tin cá nhân
    UPDATE u
    SET u.UpdatedAt = GETUTCDATE()
    FROM dbo.AspNetUsers u
    INNER JOIN inserted i ON u.Id = i.Id;
END
GO

PRINT N'✓ Trigger 3: tr_Users_UpdateTimestamp đã tạo thành công.';
GO

-- =============================================
-- TRIGGER 4: tr_Products_LowStockNotification
-- Loại: AFTER UPDATE
-- Mục đích: Gửi thông báo khi tồn kho xuống thấp
-- =============================================
IF OBJECT_ID('dbo.tr_Products_LowStockNotification', 'TR') IS NOT NULL
    DROP TRIGGER dbo.tr_Products_LowStockNotification;
GO

CREATE TRIGGER tr_Products_LowStockNotification
ON dbo.Products
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Ngưỡng cảnh báo tồn kho thấp (có thể điều chỉnh)
    DECLARE @Threshold INT = 10;
    
    -- Chỉ gửi thông báo khi tồn kho giảm xuống dưới ngưỡng
    -- So sánh giá trị cũ (deleted) và mới (inserted) để biết có vượt ngưỡng không
    INSERT INTO dbo.Notifications (UserId, Message, CreatedAt)
    SELECT 
        (SELECT TOP 1 ur.UserId 
         FROM dbo.AspNetUserRoles ur 
         INNER JOIN dbo.AspNetRoles r ON ur.RoleId = r.Id 
         WHERE r.Name = 'Admin'),
        N'Cảnh báo: Sản phẩm "' + i.Title + N'" còn ' + CAST(i.Stock AS NVARCHAR(10)) + N' trong kho.',
        GETUTCDATE()
    FROM inserted i
    INNER JOIN deleted d ON i.ProductId = d.ProductId
    WHERE i.Stock < @Threshold AND d.Stock >= @Threshold;
END
GO

PRINT N'✓ Trigger 4: tr_Products_LowStockNotification đã tạo thành công.';
GO

-- =============================================
-- TRIGGER 5: tr_Products_OutOfStockNotification
-- Loại: AFTER UPDATE  
-- Mục đích: Gửi cảnh báo khẩn cấp khi sản phẩm hết hàng
-- =============================================
IF OBJECT_ID('dbo.tr_Products_OutOfStockNotification', 'TR') IS NOT NULL
    DROP TRIGGER dbo.tr_Products_OutOfStockNotification;
GO

CREATE TRIGGER tr_Products_OutOfStockNotification
ON dbo.Products
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Gửi thông báo cho Admin khi sản phẩm vừa hết hàng
    -- Điều kiện: tồn kho cũ > 0, tồn kho mới <= 0
    INSERT INTO dbo.Notifications (UserId, Message, CreatedAt)
    SELECT 
        (SELECT TOP 1 ur.UserId 
         FROM dbo.AspNetUserRoles ur 
         INNER JOIN dbo.AspNetRoles r ON ur.RoleId = r.Id 
         WHERE r.Name = 'Admin'),
        N'🚨 Hết hàng: Sản phẩm "' + i.Title + N'" đã hết hàng!',
        GETUTCDATE()
    FROM inserted i
    INNER JOIN deleted d ON i.ProductId = d.ProductId
    WHERE i.Stock <= 0 AND d.Stock > 0;
END
GO

PRINT N'✓ Trigger 5: tr_Products_OutOfStockNotification đã tạo thành công.';
GO

-- =============================================
-- TRIGGER 6: tr_Reviews_SetCreatedAt
-- Loại: AFTER INSERT
-- Mục đích: Tự động gán thời gian cho đánh giá mới
-- =============================================
IF OBJECT_ID('dbo.tr_Reviews_SetCreatedAt', 'TR') IS NOT NULL
    DROP TRIGGER dbo.tr_Reviews_SetCreatedAt;
GO

CREATE TRIGGER tr_Reviews_SetCreatedAt
ON dbo.Reviews
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Gán thời gian hiện tại cho review nếu chưa có
    UPDATE r
    SET r.CreatedAt = GETUTCDATE()
    FROM dbo.Reviews r
    INNER JOIN inserted i ON r.ReviewId = i.ReviewId
    WHERE r.CreatedAt IS NULL;
END
GO

PRINT N'✓ Trigger 6: tr_Reviews_SetCreatedAt đã tạo thành công.';
GO

-- =============================================
-- TRIGGER 7: tr_Orders_NotifyNewOrder
-- Loại: AFTER INSERT
-- Mục đích: Thông báo cho Admin khi có đơn hàng mới
-- =============================================
IF OBJECT_ID('dbo.tr_Orders_NotifyNewOrder', 'TR') IS NOT NULL
    DROP TRIGGER dbo.tr_Orders_NotifyNewOrder;
GO

CREATE TRIGGER tr_Orders_NotifyNewOrder
ON dbo.Orders
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Tạo thông báo cho Admin mỗi khi có đơn hàng mới
    -- Hiển thị mã đơn và tổng tiền để Admin nắm được thông tin nhanh
    INSERT INTO dbo.Notifications (UserId, Message, CreatedAt)
    SELECT 
        (SELECT TOP 1 ur.UserId 
         FROM dbo.AspNetUserRoles ur 
         INNER JOIN dbo.AspNetRoles r ON ur.RoleId = r.Id 
         WHERE r.Name = 'Admin'),
        N'🛒 Đơn hàng mới #' + CAST(i.OrderId AS NVARCHAR(10)) + 
        N' - Tổng tiền: ' + FORMAT(i.Total, 'N0') + N' VND',
        GETUTCDATE()
    FROM inserted i;
END
GO

PRINT N'✓ Trigger 7: tr_Orders_NotifyNewOrder đã tạo thành công.';
GO

-- =============================================
-- TRIGGER 8: tr_Orders_StatusChangeNotification
-- Loại: AFTER UPDATE
-- Mục đích: Thông báo cho khách hàng khi trạng thái đơn hàng thay đổi
-- =============================================
IF OBJECT_ID('dbo.tr_Orders_StatusChangeNotification', 'TR') IS NOT NULL
    DROP TRIGGER dbo.tr_Orders_StatusChangeNotification;
GO

CREATE TRIGGER tr_Orders_StatusChangeNotification
ON dbo.Orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Chỉ gửi thông báo khi trạng thái đơn hàng thực sự thay đổi
    -- So sánh OrderStatus cũ và mới, nếu khác nhau thì mới tạo notification
    INSERT INTO dbo.Notifications (UserId, Message, CreatedAt)
    SELECT 
        i.UserId,
        N'📦 Đơn hàng #' + CAST(i.OrderId AS NVARCHAR(10)) + 
        N' đã chuyển trạng thái: ' + d.OrderStatus + N' → ' + i.OrderStatus,
        GETUTCDATE()
    FROM inserted i
    INNER JOIN deleted d ON i.OrderId = d.OrderId
    WHERE i.OrderStatus <> d.OrderStatus;
END
GO

PRINT N'✓ Trigger 8: tr_Orders_StatusChangeNotification đã tạo thành công.';
GO

-- =============================================
-- TRIGGER 9: tr_CartItems_SetAddedAt
-- Loại: AFTER INSERT
-- Mục đích: Tự động gán thời gian thêm vào giỏ hàng
-- =============================================
IF OBJECT_ID('dbo.tr_CartItems_SetAddedAt', 'TR') IS NOT NULL
    DROP TRIGGER dbo.tr_CartItems_SetAddedAt;
GO

CREATE TRIGGER tr_CartItems_SetAddedAt
ON dbo.CartItems
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Ghi lại thời điểm khách hàng thêm sản phẩm vào giỏ
    UPDATE c
    SET c.DateAdded = GETUTCDATE()
    FROM dbo.CartItems c
    INNER JOIN inserted i ON c.CartItemId = i.CartItemId
    WHERE c.DateAdded IS NULL;
END
GO

PRINT N'✓ Trigger 9: tr_CartItems_SetAddedAt đã tạo thành công.';
GO

-- =============================================
-- TRIGGER 10: tr_Products_PriceChangeLog
-- Loại: AFTER UPDATE
-- Mục đích: Ghi log khi giá sản phẩm thay đổi đáng kể (trên 10%)
-- =============================================
IF OBJECT_ID('dbo.tr_Products_PriceChangeLog', 'TR') IS NOT NULL
    DROP TRIGGER dbo.tr_Products_PriceChangeLog;
GO

CREATE TRIGGER tr_Products_PriceChangeLog
ON dbo.Products
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Chỉ log khi giá thay đổi trên 10% so với giá cũ
    -- Giúp Admin theo dõi các thay đổi giá lớn, tránh nhầm lẫn
    INSERT INTO dbo.Notifications (UserId, Message, CreatedAt)
    SELECT 
        (SELECT TOP 1 ur.UserId 
         FROM dbo.AspNetUserRoles ur 
         INNER JOIN dbo.AspNetRoles r ON ur.RoleId = r.Id 
         WHERE r.Name = 'Admin'),
        N'💰 Thay đổi giá: "' + i.Title + N'" từ ' + 
        FORMAT(d.Price, 'N0') + N' → ' + FORMAT(i.Price, 'N0') + N' VND',
        GETUTCDATE()
    FROM inserted i
    INNER JOIN deleted d ON i.ProductId = d.ProductId
    WHERE d.Price > 0 
    AND ABS(i.Price - d.Price) / d.Price > 0.10;
END
GO

PRINT N'✓ Trigger 10: tr_Products_PriceChangeLog đã tạo thành công.';
GO

-- =============================================
-- Tổng kết
-- =============================================
PRINT N'';
PRINT N'=============================================';
PRINT N'Đã tạo thành công tất cả 10 triggers!';
PRINT N'=============================================';
PRINT N'';
PRINT N'Trigger AFTER INSERT (4 cái):';
PRINT N'  1. tr_Products_SetCreatedAt      - Gán thời gian tạo sản phẩm';
PRINT N'  2. tr_Orders_SetCreatedAt        - Gán thời gian tạo đơn hàng';
PRINT N'  6. tr_Reviews_SetCreatedAt       - Gán thời gian đánh giá';
PRINT N'  9. tr_CartItems_SetAddedAt       - Gán thời gian thêm giỏ hàng';
PRINT N'';
PRINT N'Trigger AFTER UPDATE (5 cái):';
PRINT N'  3. tr_Users_UpdateTimestamp      - Cập nhật thời gian sửa user';
PRINT N'  4. tr_Products_LowStockNotification   - Cảnh báo tồn kho thấp';
PRINT N'  5. tr_Products_OutOfStockNotification - Cảnh báo hết hàng';
PRINT N'  8. tr_Orders_StatusChangeNotification - Thông báo đổi trạng thái';
PRINT N'  10. tr_Products_PriceChangeLog   - Log thay đổi giá lớn';
PRINT N'';
PRINT N'Trigger AFTER INSERT + Thông báo (1 cái):';
PRINT N'  7. tr_Orders_NotifyNewOrder      - Thông báo đơn hàng mới';
PRINT N'=============================================';
GO
