USE BookstoreDb;
GO

-- =============================================
-- PROCEDURE 1: sp_GetDashboardStats
-- Mục đích: Lấy thống kê tổng quan cho trang Admin Dashboard
-- Trả về: Tổng số sản phẩm, đơn hàng, doanh thu, user, etc.
-- =============================================
IF OBJECT_ID('dbo.sp_GetDashboardStats', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetDashboardStats;
GO

CREATE PROCEDURE sp_GetDashboardStats
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Trả về 1 dòng kết quả chứa tất cả các thống kê quan trọng
    SELECT 
        -- Thống kê sản phẩm
        (SELECT COUNT(*) FROM dbo.Products) AS TotalProducts,
        (SELECT COUNT(*) FROM dbo.Products WHERE IsActive = 1) AS ActiveProducts,
        (SELECT COUNT(*) FROM dbo.Products WHERE Stock < 10 AND IsActive = 1) AS LowStockProducts,
        (SELECT COUNT(*) FROM dbo.Products WHERE Stock = 0 AND IsActive = 1) AS OutOfStockProducts,
        
        -- Thống kê danh mục
        (SELECT COUNT(*) FROM dbo.Categories) AS TotalCategories,
        
        -- Thống kê đơn hàng theo trạng thái
        (SELECT COUNT(*) FROM dbo.Orders) AS TotalOrders,
        (SELECT COUNT(*) FROM dbo.Orders WHERE OrderStatus = 'Pending') AS PendingOrders,
        (SELECT COUNT(*) FROM dbo.Orders WHERE OrderStatus = 'Processing') AS ProcessingOrders,
        (SELECT COUNT(*) FROM dbo.Orders WHERE OrderStatus = 'Delivered') AS DeliveredOrders,
        
        -- Thống kê doanh thu
        (SELECT ISNULL(SUM(Total), 0) FROM dbo.Orders WHERE PaymentStatus = 'Paid') AS TotalRevenue,
        (SELECT ISNULL(SUM(Total), 0) FROM dbo.Orders 
         WHERE PaymentStatus = 'Paid' AND CAST(OrderDate AS DATE) = CAST(GETUTCDATE() AS DATE)) AS TodayRevenue,
        (SELECT ISNULL(SUM(Total), 0) FROM dbo.Orders 
         WHERE PaymentStatus = 'Paid' AND OrderDate >= DATEADD(DAY, -7, GETUTCDATE())) AS WeekRevenue,
        
        -- Thống kê người dùng
        (SELECT COUNT(*) FROM dbo.AspNetUsers) AS TotalUsers,
        (SELECT COUNT(*) FROM dbo.AspNetUsers WHERE IsActive = 1) AS ActiveUsers;
END
GO

PRINT N'✓ Procedure 1: sp_GetDashboardStats đã tạo thành công.';
GO

-- =============================================
-- PROCEDURE 2: sp_SearchProducts
-- Mục đích: Tìm kiếm và lọc sản phẩm với phân trang
-- Tham số: Danh mục, từ khóa, giá, sắp xếp, phân trang
-- =============================================
IF OBJECT_ID('dbo.sp_SearchProducts', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_SearchProducts;
GO

CREATE PROCEDURE sp_SearchProducts
    @CategoryId INT = NULL,              -- Lọc theo danh mục (NULL = tất cả)
    @SearchTerm NVARCHAR(100) = NULL,    -- Tìm theo tên hoặc tác giả
    @MinPrice DECIMAL(18,2) = NULL,      -- Giá tối thiểu
    @MaxPrice DECIMAL(18,2) = NULL,      -- Giá tối đa
    @InStockOnly BIT = 0,                -- Chỉ lấy sản phẩm còn hàng
    @SortBy NVARCHAR(20) = 'CreatedAt',  -- Sắp xếp theo: Price, Title, CreatedAt
    @SortOrder NVARCHAR(4) = 'DESC',     -- ASC hoặc DESC
    @PageNumber INT = 1,                 -- Trang hiện tại
    @PageSize INT = 12                   -- Số sản phẩm mỗi trang
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Tính offset cho phân trang
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    -- Đếm tổng số sản phẩm thỏa điều kiện
    DECLARE @TotalCount INT;
    SELECT @TotalCount = COUNT(*)
    FROM dbo.Products p
    WHERE p.IsActive = 1
    AND (@CategoryId IS NULL OR p.CategoryId = @CategoryId)
    AND (@SearchTerm IS NULL OR p.Title LIKE '%' + @SearchTerm + '%' OR p.Author LIKE '%' + @SearchTerm + '%')
    AND (@MinPrice IS NULL OR p.Price >= @MinPrice)
    AND (@MaxPrice IS NULL OR p.Price <= @MaxPrice)
    AND (@InStockOnly = 0 OR p.Stock > 0);
    
    -- Lấy danh sách sản phẩm theo điều kiện
    SELECT 
        p.ProductId,
        p.Title,
        p.Author,
        p.Description,
        p.Price,
        p.Stock,
        p.CategoryId,
        c.Name AS CategoryName,
        (SELECT TOP 1 ImageUrl FROM dbo.ProductImages WHERE ProductId = p.ProductId AND IsMain = 1) AS MainImageUrl,
        @TotalCount AS TotalCount,
        CEILING(@TotalCount * 1.0 / @PageSize) AS TotalPages
    FROM dbo.Products p
    LEFT JOIN dbo.Categories c ON p.CategoryId = c.CategoryId
    WHERE p.IsActive = 1
    AND (@CategoryId IS NULL OR p.CategoryId = @CategoryId)
    AND (@SearchTerm IS NULL OR p.Title LIKE '%' + @SearchTerm + '%' OR p.Author LIKE '%' + @SearchTerm + '%')
    AND (@MinPrice IS NULL OR p.Price >= @MinPrice)
    AND (@MaxPrice IS NULL OR p.Price <= @MaxPrice)
    AND (@InStockOnly = 0 OR p.Stock > 0)
    ORDER BY 
        CASE WHEN @SortBy = 'Price' AND @SortOrder = 'ASC' THEN p.Price END ASC,
        CASE WHEN @SortBy = 'Price' AND @SortOrder = 'DESC' THEN p.Price END DESC,
        CASE WHEN @SortBy = 'Title' AND @SortOrder = 'ASC' THEN p.Title END ASC,
        CASE WHEN @SortBy = 'Title' AND @SortOrder = 'DESC' THEN p.Title END DESC,
        CASE WHEN @SortBy = 'CreatedAt' AND @SortOrder = 'ASC' THEN p.CreatedAt END ASC,
        CASE WHEN @SortBy = 'CreatedAt' AND @SortOrder = 'DESC' THEN p.CreatedAt END DESC
    OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

PRINT N'✓ Procedure 2: sp_SearchProducts đã tạo thành công.';
GO

-- =============================================
-- PROCEDURE 3: sp_GetOrderDetails
-- Mục đích: Lấy chi tiết đơn hàng đầy đủ
-- Trả về: 3 result set (Order info, Order items, Payments)
-- =============================================
IF OBJECT_ID('dbo.sp_GetOrderDetails', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetOrderDetails;
GO

CREATE PROCEDURE sp_GetOrderDetails
    @OrderId INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Result set 1: Thông tin đơn hàng chính
    SELECT 
        o.OrderId,
        o.OrderNumber,
        o.OrderDate,
        o.Total,
        o.OrderStatus,
        o.PaymentMethod,
        o.PaymentStatus,
        o.ShippingName,
        o.ShippingPhone,
        o.ShippingEmail,
        o.ShippingAddress,
        o.TrackingNumber,
        o.Notes,
        u.Email AS CustomerEmail,
        u.FullName AS CustomerName
    FROM dbo.Orders o
    LEFT JOIN dbo.AspNetUsers u ON o.UserId = u.Id
    WHERE o.OrderId = @OrderId;
    
    -- Result set 2: Danh sách sản phẩm trong đơn
    SELECT 
        oi.OrderItemId,
        oi.ProductId,
        oi.Quantity,
        oi.UnitPrice,
        p.Title AS ProductTitle,
        p.Author AS ProductAuthor,
        (SELECT TOP 1 ImageUrl FROM dbo.ProductImages WHERE ProductId = p.ProductId AND IsMain = 1) AS ProductImageUrl,
        (oi.Quantity * oi.UnitPrice) AS Subtotal
    FROM dbo.OrderItems oi
    INNER JOIN dbo.Products p ON oi.ProductId = p.ProductId
    WHERE oi.OrderId = @OrderId;
    
    -- Result set 3: Lịch sử thanh toán
    SELECT 
        PaymentId,
        PaymentMethod,
        Status,
        PaymentDate,
        Amount,
        TransactionId
    FROM dbo.Payments
    WHERE OrderId = @OrderId
    ORDER BY PaymentDate DESC;
END
GO

PRINT N'✓ Procedure 3: sp_GetOrderDetails đã tạo thành công.';
GO

-- =============================================
-- PROCEDURE 4: sp_CreateOrder
-- Mục đích: Tạo đơn hàng mới từ giỏ hàng (có transaction)
-- Tham số OUTPUT: @OrderId - Trả về ID đơn hàng vừa tạo
-- Minh họa: BEGIN TRANSACTION, TRY/CATCH, ROLLBACK
-- =============================================
IF OBJECT_ID('dbo.sp_CreateOrder', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_CreateOrder;
GO

CREATE PROCEDURE sp_CreateOrder
    @UserId NVARCHAR(450),
    @ShippingName NVARCHAR(100),
    @ShippingPhone NVARCHAR(20),
    @ShippingEmail NVARCHAR(256),
    @ShippingAddress NVARCHAR(500),
    @PaymentMethod NVARCHAR(50),
    @Notes NVARCHAR(1000) = NULL,
    @OrderId INT OUTPUT              -- Tham số đầu ra để trả về OrderId
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Bắt đầu transaction để đảm bảo tính toàn vẹn dữ liệu
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Bước 1: Kiểm tra giỏ hàng có sản phẩm không
        IF NOT EXISTS (SELECT 1 FROM dbo.CartItems WHERE UserId = @UserId)
        BEGIN
            RAISERROR(N'Giỏ hàng trống.', 16, 1);
            RETURN;
        END
        
        -- Bước 2: Kiểm tra sản phẩm còn hàng không
        IF EXISTS (
            SELECT 1 FROM dbo.CartItems ci
            INNER JOIN dbo.Products p ON ci.ProductId = p.ProductId
            WHERE ci.UserId = @UserId
            AND ci.Quantity > p.Stock
        )
        BEGIN
            RAISERROR(N'Một hoặc nhiều sản phẩm không đủ số lượng trong kho.', 16, 1);
            RETURN;
        END
        
        -- Bước 3: Tính tổng tiền đơn hàng từ giỏ hàng
        DECLARE @Total DECIMAL(18, 2);
        SELECT @Total = SUM(p.Price * ci.Quantity)
        FROM dbo.CartItems ci
        INNER JOIN dbo.Products p ON ci.ProductId = p.ProductId
        WHERE ci.UserId = @UserId
        AND p.IsActive = 1;
        
        -- Bước 4: Tạo đơn hàng mới
        INSERT INTO dbo.Orders (
            UserId, OrderDate, Total, ShippingName, ShippingPhone,
            ShippingEmail, ShippingAddress, PaymentMethod, PaymentStatus,
            OrderStatus, Notes
        )
        VALUES (
            @UserId, GETUTCDATE(), @Total, @ShippingName, @ShippingPhone,
            @ShippingEmail, @ShippingAddress, @PaymentMethod,
            CASE WHEN @PaymentMethod = 'COD' THEN 'COD' ELSE 'Pending' END,
            'Pending', @Notes
        );
        
        -- Lấy OrderId vừa tạo
        SET @OrderId = SCOPE_IDENTITY();
        
        -- Bước 5: Copy các sản phẩm từ giỏ hàng sang OrderItems
        INSERT INTO dbo.OrderItems (OrderId, ProductId, Quantity, UnitPrice)
        SELECT 
            @OrderId,
            ci.ProductId,
            ci.Quantity,
            p.Price
        FROM dbo.CartItems ci
        INNER JOIN dbo.Products p ON ci.ProductId = p.ProductId
        WHERE ci.UserId = @UserId
        AND p.IsActive = 1;
        
        -- Bước 6: Giảm số lượng tồn kho
        UPDATE p
        SET p.Stock = p.Stock - ci.Quantity
        FROM dbo.Products p
        INNER JOIN dbo.CartItems ci ON p.ProductId = ci.ProductId
        WHERE ci.UserId = @UserId;
        
        -- Bước 7: Xóa giỏ hàng sau khi đặt thành công
        DELETE FROM dbo.CartItems WHERE UserId = @UserId;
        
        -- Commit nếu tất cả đều OK
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Rollback nếu có lỗi xảy ra
        ROLLBACK TRANSACTION;
        
        -- Ném lỗi ra ngoài để .NET bắt được
        THROW;
    END CATCH
END
GO

PRINT N'✓ Procedure 4: sp_CreateOrder đã tạo thành công.';
GO

-- =============================================
-- PROCEDURE 5: sp_UpdateOrderStatus
-- Mục đích: Cập nhật trạng thái đơn hàng với validation
-- Minh họa: Business logic validation, conditional update
-- =============================================
IF OBJECT_ID('dbo.sp_UpdateOrderStatus', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_UpdateOrderStatus;
GO

CREATE PROCEDURE sp_UpdateOrderStatus
    @OrderId INT,
    @NewStatus NVARCHAR(50),
    @TrackingNumber NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Lấy trạng thái hiện tại của đơn hàng
    DECLARE @CurrentStatus NVARCHAR(50);
    SELECT @CurrentStatus = OrderStatus FROM dbo.Orders WHERE OrderId = @OrderId;
    
    -- Kiểm tra đơn hàng có tồn tại không
    IF @CurrentStatus IS NULL
    BEGIN
        RAISERROR(N'Không tìm thấy đơn hàng.', 16, 1);
        RETURN;
    END
    
    -- Validate trạng thái mới có hợp lệ không
    IF @NewStatus NOT IN ('Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled')
    BEGIN
        RAISERROR(N'Trạng thái đơn hàng không hợp lệ.', 16, 1);
        RETURN;
    END
    
    -- Không cho phép sửa đơn đã hoàn thành hoặc đã hủy
    IF @CurrentStatus IN ('Delivered', 'Cancelled')
    BEGIN
        RAISERROR(N'Không thể thay đổi trạng thái đơn hàng đã hoàn thành hoặc đã hủy.', 16, 1);
        RETURN;
    END
    
    -- Cập nhật trạng thái đơn hàng
    UPDATE dbo.Orders
    SET OrderStatus = @NewStatus,
        TrackingNumber = CASE WHEN @NewStatus = 'Shipped' THEN @TrackingNumber ELSE TrackingNumber END
    WHERE OrderId = @OrderId;
    
    -- Tạo thông báo cho khách hàng
    DECLARE @UserId NVARCHAR(450);
    SELECT @UserId = UserId FROM dbo.Orders WHERE OrderId = @OrderId;
    
    INSERT INTO dbo.Notifications (UserId, Message, CreatedAt)
    VALUES (
        @UserId,
        N'📦 Đơn hàng #' + CAST(@OrderId AS NVARCHAR(10)) + N' đã chuyển sang: ' + @NewStatus,
        GETUTCDATE()
    );
END
GO

PRINT N'✓ Procedure 5: sp_UpdateOrderStatus đã tạo thành công.';
GO

-- =============================================
-- PROCEDURE 6: sp_GetUserOrders
-- Mục đích: Lấy danh sách đơn hàng của user với phân trang
-- Minh họa: Subquery, pagination, optional filter
-- =============================================
IF OBJECT_ID('dbo.sp_GetUserOrders', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetUserOrders;
GO

CREATE PROCEDURE sp_GetUserOrders
    @UserId NVARCHAR(450),
    @Status NVARCHAR(50) = NULL,     -- Lọc theo trạng thái (NULL = tất cả)
    @PageNumber INT = 1,
    @PageSize INT = 10
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    SELECT 
        o.OrderId,
        o.OrderNumber,
        o.OrderDate,
        o.Total,
        o.OrderStatus,
        o.PaymentMethod,
        o.PaymentStatus,
        -- Đếm số sản phẩm trong đơn
        (SELECT COUNT(*) FROM dbo.OrderItems WHERE OrderId = o.OrderId) AS ItemCount,
        -- Lấy ảnh sản phẩm đầu tiên để hiển thị
        (SELECT TOP 1 pi.ImageUrl 
         FROM dbo.OrderItems oi 
         INNER JOIN dbo.ProductImages pi ON oi.ProductId = pi.ProductId AND pi.IsMain = 1
         WHERE oi.OrderId = o.OrderId) AS FirstProductImage
    FROM dbo.Orders o
    WHERE o.UserId = @UserId
    AND (@Status IS NULL OR o.OrderStatus = @Status)
    ORDER BY o.OrderDate DESC
    OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

PRINT N'✓ Procedure 6: sp_GetUserOrders đã tạo thành công.';
GO

-- =============================================
-- PROCEDURE 7: sp_AddToCart
-- Mục đích: Thêm sản phẩm vào giỏ hàng
-- Minh họa: UPSERT pattern (INSERT hoặc UPDATE)
-- =============================================
IF OBJECT_ID('dbo.sp_AddToCart', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_AddToCart;
GO

CREATE PROCEDURE sp_AddToCart
    @UserId NVARCHAR(450),
    @ProductId INT,
    @Quantity INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Kiểm tra sản phẩm có tồn tại và còn bán không
    DECLARE @CurrentStock INT;
    SELECT @CurrentStock = Stock 
    FROM dbo.Products 
    WHERE ProductId = @ProductId AND IsActive = 1;
    
    IF @CurrentStock IS NULL
    BEGIN
        RAISERROR(N'Sản phẩm không tồn tại hoặc đã ngừng bán.', 16, 1);
        RETURN;
    END
    
    -- Kiểm tra tồn kho còn đủ không
    DECLARE @CurrentCartQuantity INT = ISNULL((
        SELECT Quantity FROM dbo.CartItems 
        WHERE UserId = @UserId AND ProductId = @ProductId
    ), 0);
    
    IF @CurrentCartQuantity + @Quantity > @CurrentStock
    BEGIN
        RAISERROR(N'Không đủ hàng trong kho.', 16, 1);
        RETURN;
    END
    
    -- UPSERT: Nếu đã có trong giỏ thì tăng số lượng, chưa có thì thêm mới
    IF EXISTS (SELECT 1 FROM dbo.CartItems WHERE UserId = @UserId AND ProductId = @ProductId)
    BEGIN
        UPDATE dbo.CartItems
        SET Quantity = Quantity + @Quantity
        WHERE UserId = @UserId AND ProductId = @ProductId;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.CartItems (UserId, ProductId, Quantity, DateAdded)
        VALUES (@UserId, @ProductId, @Quantity, GETUTCDATE());
    END
    
    -- Trả về tổng số sản phẩm trong giỏ
    SELECT SUM(Quantity) AS CartCount 
    FROM dbo.CartItems 
    WHERE UserId = @UserId;
END
GO

PRINT N'✓ Procedure 7: sp_AddToCart đã tạo thành công.';
GO

-- =============================================
-- PROCEDURE 8: sp_GetTopSellingProducts
-- Mục đích: Lấy danh sách sản phẩm bán chạy nhất
-- Minh hịa: Aggregation (SUM, GROUP BY), ranking
-- =============================================
IF OBJECT_ID('dbo.sp_GetTopSellingProducts', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetTopSellingProducts;
GO

CREATE PROCEDURE sp_GetTopSellingProducts
    @TopN INT = 10,                   -- Lấy top bao nhiêu sản phẩm
    @StartDate DATE = NULL,           -- Lọc theo khoảng thời gian (tùy chọn)
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT TOP (@TopN)
        p.ProductId,
        p.Title,
        p.Author,
        p.Price,
        c.Name AS CategoryName,
        (SELECT TOP 1 ImageUrl FROM dbo.ProductImages WHERE ProductId = p.ProductId AND IsMain = 1) AS MainImageUrl,
        -- Tổng số lượng đã bán
        SUM(oi.Quantity) AS TotalSold,
        -- Tổng doanh thu từ sản phẩm này
        SUM(oi.Quantity * oi.UnitPrice) AS TotalRevenue
    FROM dbo.Products p
    INNER JOIN dbo.OrderItems oi ON p.ProductId = oi.ProductId
    INNER JOIN dbo.Orders o ON oi.OrderId = o.OrderId
    LEFT JOIN dbo.Categories c ON p.CategoryId = c.CategoryId
    WHERE o.PaymentStatus = 'Paid'
    AND (@StartDate IS NULL OR CAST(o.OrderDate AS DATE) >= @StartDate)
    AND (@EndDate IS NULL OR CAST(o.OrderDate AS DATE) <= @EndDate)
    GROUP BY p.ProductId, p.Title, p.Author, p.Price, c.Name
    ORDER BY TotalSold DESC;
END
GO

PRINT N'✓ Procedure 8: sp_GetTopSellingProducts đã tạo thành công.';
GO

-- =============================================
-- PROCEDURE 9: sp_GetDailyRevenue
-- Mục đích: Thống kê doanh thu theo ngày
-- Minh họa: GROUP BY date, aggregate functions (SUM, COUNT, AVG)
-- =============================================
IF OBJECT_ID('dbo.sp_GetDailyRevenue', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetDailyRevenue;
GO

CREATE PROCEDURE sp_GetDailyRevenue
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Thống kê doanh thu theo từng ngày
    SELECT 
        CAST(OrderDate AS DATE) AS ReportDate,
        COUNT(*) AS OrderCount,                    -- Số đơn hàng
        SUM(Total) AS TotalRevenue,                -- Tổng doanh thu
        AVG(Total) AS AverageOrderValue,           -- Giá trị đơn trung bình
        MIN(Total) AS MinOrderValue,               -- Đơn thấp nhất
        MAX(Total) AS MaxOrderValue                -- Đơn cao nhất
    FROM dbo.Orders
    WHERE PaymentStatus = 'Paid'
    AND CAST(OrderDate AS DATE) BETWEEN @StartDate AND @EndDate
    GROUP BY CAST(OrderDate AS DATE)
    ORDER BY ReportDate;
END
GO

PRINT N'✓ Procedure 9: sp_GetDailyRevenue đã tạo thành công.';
GO

-- =============================================
-- PROCEDURE 10: sp_GetCategoryStatistics
-- Mục đích: Thống kê sản phẩm và doanh thu theo từng danh mục
-- Minh họa: Multiple JOINs, GROUP BY, aggregate functions
-- =============================================
IF OBJECT_ID('dbo.sp_GetCategoryStatistics', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetCategoryStatistics;
GO

CREATE PROCEDURE sp_GetCategoryStatistics
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Thống kê chi tiết cho từng danh mục
    SELECT 
        c.CategoryId,
        c.Name AS CategoryName,
        COUNT(DISTINCT p.ProductId) AS TotalProducts,
        COUNT(DISTINCT CASE WHEN p.Stock > 0 THEN p.ProductId END) AS InStockProducts,
        -- Tổng số lượng đã bán (từ OrderItems)
        ISNULL(SUM(oi.Quantity), 0) AS TotalSold,
        -- Tổng doanh thu từ danh mục này
        ISNULL(SUM(oi.Quantity * oi.UnitPrice), 0) AS TotalRevenue
    FROM dbo.Categories c
    LEFT JOIN dbo.Products p ON c.CategoryId = p.CategoryId AND p.IsActive = 1
    LEFT JOIN dbo.OrderItems oi ON p.ProductId = oi.ProductId
    LEFT JOIN dbo.Orders o ON oi.OrderId = o.OrderId AND o.PaymentStatus = 'Paid'
    GROUP BY c.CategoryId, c.Name
    ORDER BY TotalRevenue DESC;
END
GO

PRINT N'✓ Procedure 10: sp_GetCategoryStatistics đã tạo thành công.';
GO

-- =============================================
-- PROCEDURE 11: sp_GetTopCustomers
-- Mục đích: Lấy danh sách khách hàng mua nhiều nhất
-- Minh họa: TOP clause, multiple aggregations
-- =============================================
IF OBJECT_ID('dbo.sp_GetTopCustomers', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetTopCustomers;
GO

CREATE PROCEDURE sp_GetTopCustomers
    @TopN INT = 10
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT TOP (@TopN)
        u.Id AS UserId,
        u.FullName,
        u.Email,
        u.PhoneNumber,
        -- Số đơn hàng đã đặt
        COUNT(o.OrderId) AS OrderCount,
        -- Tổng tiền đã chi
        SUM(o.Total) AS TotalSpent,
        -- Đơn hàng đầu tiên
        MIN(o.OrderDate) AS FirstOrderDate,
        -- Đơn hàng gần nhất
        MAX(o.OrderDate) AS LastOrderDate
    FROM dbo.AspNetUsers u
    INNER JOIN dbo.Orders o ON u.Id = o.UserId
    WHERE o.PaymentStatus = 'Paid'
    GROUP BY u.Id, u.FullName, u.Email, u.PhoneNumber
    ORDER BY TotalSpent DESC;
END
GO

PRINT N'✓ Procedure 11: sp_GetTopCustomers đã tạo thành công.';
GO

-- =============================================
-- PROCEDURE 12: sp_UpdateCartItemQuantity
-- Mục đích: Cập nhật số lượng sản phẩm trong giỏ hàng
-- Minh họa: UPDATE with validation
-- =============================================
IF OBJECT_ID('dbo.sp_UpdateCartItemQuantity', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_UpdateCartItemQuantity;
GO

CREATE PROCEDURE sp_UpdateCartItemQuantity
    @CartItemId INT,
    @NewQuantity INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Kiểm tra số lượng hợp lệ
    IF @NewQuantity <= 0
    BEGIN
        RAISERROR(N'Số lượng phải lớn hơn 0.', 16, 1);
        RETURN;
    END
    
    -- Lấy ProductId và kiểm tra tồn kho
    DECLARE @ProductId INT;
    DECLARE @AvailableStock INT;
    
    SELECT @ProductId = ProductId 
    FROM dbo.CartItems 
    WHERE CartItemId = @CartItemId;
    
    IF @ProductId IS NULL
    BEGIN
        RAISERROR(N'Không tìm thấy sản phẩm trong giỏ hàng.', 16, 1);
        RETURN;
    END
    
    SELECT @AvailableStock = Stock 
    FROM dbo.Products 
    WHERE ProductId = @ProductId;
    
    IF @NewQuantity > @AvailableStock
    BEGIN
        RAISERROR(N'Số lượng vượt quá tồn kho hiện có.', 16, 1);
        RETURN;
    END
    
    -- Cập nhật số lượng
    UPDATE dbo.CartItems
    SET Quantity = @NewQuantity
    WHERE CartItemId = @CartItemId;
END
GO

PRINT N'✓ Procedure 12: sp_UpdateCartItemQuantity đã tạo thành công.';
GO

-- =============================================
-- PROCEDURE 13: sp_ClearUserCart
-- Mục đích: Xóa toàn bộ giỏ hàng của user
-- Minh họa: Simple DELETE operation
-- =============================================
IF OBJECT_ID('dbo.sp_ClearUserCart', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_ClearUserCart;
GO

CREATE PROCEDURE sp_ClearUserCart
    @UserId NVARCHAR(450)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Xóa tất cả sản phẩm trong giỏ hàng
    DELETE FROM dbo.CartItems
    WHERE UserId = @UserId;
    
    -- Trả về số dòng đã xóa
    SELECT @@ROWCOUNT AS DeletedCount;
END
GO

PRINT N'✓ Procedure 13: sp_ClearUserCart đã tạo thành công.';
GO

-- =============================================
-- PROCEDURE 14: sp_GetLowStockProducts
-- Mục đích: Lấy danh sách sản phẩm sắp hết hàng
-- Minh họa: Simple SELECT with WHERE condition
-- =============================================
IF OBJECT_ID('dbo.sp_GetLowStockProducts', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetLowStockProducts;
GO

CREATE PROCEDURE sp_GetLowStockProducts
    @Threshold INT = 10
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Lấy các sản phẩm có tồn kho thấp hơn ngưỡng
    SELECT 
        p.ProductId,
        p.Title,
        p.Author,
        p.Price,
        p.Stock,
        c.Name AS CategoryName,
        (SELECT TOP 1 ImageUrl FROM dbo.ProductImages WHERE ProductId = p.ProductId AND IsMain = 1) AS MainImageUrl
    FROM dbo.Products p
    LEFT JOIN dbo.Categories c ON p.CategoryId = c.CategoryId
    WHERE p.IsActive = 1
    AND p.Stock < @Threshold
    ORDER BY p.Stock ASC, p.Title;
END
GO

PRINT N'✓ Procedure 14: sp_GetLowStockProducts đã tạo thành công.';
GO

-- =============================================
-- Tổng kết
-- =============================================
PRINT N'';
PRINT N'=============================================';
PRINT N'Đã tạo thành công tất cả 14 stored procedures!';
PRINT N'=============================================';
PRINT N'';
PRINT N'NHÓM 1: Thống kê & Báo cáo (5 cái)';
PRINT N'  1.  sp_GetDashboardStats           - Tổng quan dashboard';
PRINT N'  8.  sp_GetTopSellingProducts       - Top sản phẩm bán chạy';
PRINT N'  9.  sp_GetDailyRevenue             - Doanh thu theo ngày';
PRINT N'  10. sp_GetCategoryStatistics       - Thống kê theo danh mục';
PRINT N'  11. sp_GetTopCustomers             - Khách hàng VIP';
PRINT N'';
PRINT N'NHÓM 2: Quản lý sản phẩm (2 cái)';
PRINT N'  2.  sp_SearchProducts              - Tìm kiếm & lọc sản phẩm';
PRINT N'  14. sp_GetLowStockProducts         - Sản phẩm sắp hết hàng';
PRINT N'';
PRINT N'NHÓM 3: Quản lý đơn hàng (3 cái)';
PRINT N'  3.  sp_GetOrderDetails             - Chi tiết đơn hàng';
PRINT N'  4.  sp_CreateOrder                 - Tạo đơn hàng (có transaction)';
PRINT N'  5.  sp_UpdateOrderStatus           - Cập nhật trạng thái đơn';
PRINT N'';
PRINT N'NHÓM 4: Quản lý giỏ hàng (4 cái)';
PRINT N'  6.  sp_GetUserOrders               - Đơn hàng của user';
PRINT N'  7.  sp_AddToCart                   - Thêm vào giỏ';
PRINT N'  12. sp_UpdateCartItemQuantity      - Sửa số lượng giỏ hàng';
PRINT N'  13. sp_ClearUserCart               - Xóa giỏ hàng';
PRINT N'=============================================';
GO
