USE BookstoreDb;
GO

-- =============================================
-- FUNCTION 1: fn_CalculateDiscount (Scalar Function)
-- Loại: Scalar Function
-- Mục đích: Tính số tiền giảm giá dựa trên giá gốc và phần trăm
-- Minh họa: Hàm tính toán đơn giản, nhận 2 tham số, trả về 1 giá trị
-- =============================================
IF OBJECT_ID('dbo.fn_CalculateDiscount', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_CalculateDiscount;
GO

CREATE FUNCTION fn_CalculateDiscount
(
    @OriginalPrice DECIMAL(18, 2),
    @DiscountPercentage DECIMAL(5, 2)
)
RETURNS DECIMAL(18, 2)
AS
BEGIN
    DECLARE @DiscountAmount DECIMAL(18, 2);
    
    -- Tính số tiền được giảm
    -- Ví dụ: 100,000 VND với 20% giảm = 20,000 VND
    SET @DiscountAmount = @OriginalPrice * (@DiscountPercentage / 100.0);
    
    RETURN @DiscountAmount;
END
GO

PRINT N'✓ Function 1: fn_CalculateDiscount đã tạo thành công.';
GO

-- =============================================
-- FUNCTION 2: fn_CalculateFinalPrice (Scalar Function)
-- Loại: Scalar Function
-- Mục đích: Tính giá cuối cùng sau khi giảm giá
-- Minh họa: Sử dụng biểu thức toán học đơn giản
-- =============================================
IF OBJECT_ID('dbo.fn_CalculateFinalPrice', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_CalculateFinalPrice;
GO

CREATE FUNCTION fn_CalculateFinalPrice
(
    @OriginalPrice DECIMAL(18, 2),
    @DiscountPercentage DECIMAL(5, 2)
)
RETURNS DECIMAL(18, 2)
AS
BEGIN
    DECLARE @FinalPrice DECIMAL(18, 2);
    
    -- Tính giá sau khi giảm
    -- Ví dụ: 100,000 VND giảm 20% = 80,000 VND
    SET @FinalPrice = @OriginalPrice - (@OriginalPrice * @DiscountPercentage / 100.0);
    
    RETURN @FinalPrice;
END
GO

PRINT N'✓ Function 2: fn_CalculateFinalPrice đã tạo thành công.';
GO

-- =============================================
-- FUNCTION 3: fn_GetUserCartTotal (Scalar Function)
-- Loại: Scalar Function
-- Mục đích: Tính tổng tiền giỏ hàng của user
-- Minh họa: Aggregation (SUM) trong function, JOIN nhiều bảng
-- =============================================
IF OBJECT_ID('dbo.fn_GetUserCartTotal', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_GetUserCartTotal;
GO

CREATE FUNCTION fn_GetUserCartTotal
(
    @UserId NVARCHAR(450)
)
RETURNS DECIMAL(18, 2)
AS
BEGIN
    DECLARE @Total DECIMAL(18, 2);
    
    -- Tính tổng tiền = Giá sản phẩm × Số lượng
    SELECT @Total = SUM(p.Price * ci.Quantity)
    FROM dbo.CartItems ci
    INNER JOIN dbo.Products p ON ci.ProductId = p.ProductId
    WHERE ci.UserId = @UserId
    AND p.IsActive = 1;
    
    -- Trả về 0 nếu giỏ hàng trống
    RETURN ISNULL(@Total, 0);
END
GO

PRINT N'✓ Function 3: fn_GetUserCartTotal đã tạo thành công.';
GO

-- =============================================
-- FUNCTION 4: fn_GetUserCartCount (Scalar Function)
-- Loại: Scalar Function
-- Mục đích: Đếm tổng số sản phẩm trong giỏ hàng của user
-- Minh họa: Aggregation với SUM (tổng số lượng)
-- =============================================
IF OBJECT_ID('dbo.fn_GetUserCartCount', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_GetUserCartCount;
GO

CREATE FUNCTION fn_GetUserCartCount
(
    @UserId NVARCHAR(450)
)
RETURNS INT
AS
BEGIN
    DECLARE @Count INT;
    
    -- Đếm tổng số lượng sản phẩm (không phải số dòng)
    -- Ví dụ: 2 sách A + 3 sách B = 5 sản phẩm
    SELECT @Count = SUM(Quantity)
    FROM dbo.CartItems
    WHERE UserId = @UserId;
    
    RETURN ISNULL(@Count, 0);
END
GO

PRINT N'✓ Function 4: fn_GetUserCartCount đã tạo thành công.';
GO

-- =============================================
-- FUNCTION 5: fn_GetProductAverageRating (Scalar Function)
-- Loại: Scalar Function
-- Mục đích: Tính điểm đánh giá trung bình của sản phẩm
-- Minh họa: Aggregation với AVG, CAST để chuyển kiểu dữ liệu
-- =============================================
IF OBJECT_ID('dbo.fn_GetProductAverageRating', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_GetProductAverageRating;
GO

CREATE FUNCTION fn_GetProductAverageRating
(
    @ProductId INT
)
RETURNS DECIMAL(3, 2)
AS
BEGIN
    DECLARE @AvgRating DECIMAL(3, 2);
    
    -- Tính trung bình cộng điểm rating (1-5 sao)
    SELECT @AvgRating = AVG(CAST(Rating AS DECIMAL(3, 2)))
    FROM dbo.Reviews
    WHERE ProductId = @ProductId;
    
    -- Trả về 0 nếu chưa có đánh giá nào
    RETURN ISNULL(@AvgRating, 0);
END
GO

PRINT N'✓ Function 5: fn_GetProductAverageRating đã tạo thành công.';
GO

-- =============================================
-- FUNCTION 6: fn_GetProductReviewCount (Scalar Function)
-- Loại: Scalar Function
-- Mục đích: Đếm số lượng đánh giá của sản phẩm
-- Minh họa: Aggregation với COUNT
-- =============================================
IF OBJECT_ID('dbo.fn_GetProductReviewCount', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_GetProductReviewCount;
GO

CREATE FUNCTION fn_GetProductReviewCount
(
    @ProductId INT
)
RETURNS INT
AS
BEGIN
    DECLARE @Count INT;
    
    -- Đếm số review cho sản phẩm
    SELECT @Count = COUNT(*)
    FROM dbo.Reviews
    WHERE ProductId = @ProductId;
    
    RETURN ISNULL(@Count, 0);
END
GO

PRINT N'✓ Function 6: fn_GetProductReviewCount đã tạo thành công.';
GO

-- =============================================
-- FUNCTION 7: fn_FormatVNDCurrency (Scalar Function)
-- Loại: Scalar Function
-- Mục đích: Định dạng số tiền theo kiểu Việt Nam
-- Minh họa: String manipulation với FORMAT
-- =============================================
IF OBJECT_ID('dbo.fn_FormatVNDCurrency', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_FormatVNDCurrency;
GO

CREATE FUNCTION fn_FormatVNDCurrency
(
    @Amount DECIMAL(18, 2)
)
RETURNS NVARCHAR(50)
AS
BEGIN
    -- Định dạng: 100000.50 => "100,000₫"
    -- FORMAT 'N0' = Number with thousand separators, 0 decimals
    RETURN FORMAT(@Amount, 'N0') + N'₫';
END
GO

PRINT N'✓ Function 7: fn_FormatVNDCurrency đã tạo thành công.';
GO

-- =============================================
-- FUNCTION 8: fn_GetOrderStatusDisplay (Scalar Function)
-- Loại: Scalar Function
-- Mục đích: Chuyển trạng thái đơn hàng sang tiếng Việt
-- Minh họa: CASE statement để xử lý điều kiện
-- =============================================
IF OBJECT_ID('dbo.fn_GetOrderStatusDisplay', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_GetOrderStatusDisplay;
GO

CREATE FUNCTION fn_GetOrderStatusDisplay
(
    @Status NVARCHAR(50)
)
RETURNS NVARCHAR(100)
AS
BEGIN
    -- Chuyển trạng thái tiếng Anh sang tiếng Việt
    RETURN CASE @Status
        WHEN 'Pending' THEN N'Chờ xử lý'
        WHEN 'Processing' THEN N'Đang xử lý'
        WHEN 'Shipped' THEN N'Đang giao hàng'
        WHEN 'Delivered' THEN N'Đã giao hàng'
        WHEN 'Cancelled' THEN N'Đã hủy'
        ELSE @Status  -- Trả về nguyên bản nếu không khớp
    END;
END
GO

PRINT N'✓ Function 8: fn_GetOrderStatusDisplay đã tạo thành công.';
GO

-- =============================================
-- FUNCTION 9: fn_GetMonthNameVietnamese (Scalar Function)
-- Loại: Scalar Function
-- Mục đích: Chuyển số tháng (1-12) sang tên tháng tiếng Việt
-- Minh họa: CASE statement với nhiều điều kiện
-- =============================================
IF OBJECT_ID('dbo.fn_GetMonthNameVietnamese', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_GetMonthNameVietnamese;
GO

CREATE FUNCTION fn_GetMonthNameVietnamese
(
    @MonthNumber INT
)
RETURNS NVARCHAR(20)
AS
BEGIN
    -- Chuyển số tháng sang tên tháng
    RETURN CASE @MonthNumber
        WHEN 1 THEN N'Tháng Một'
        WHEN 2 THEN N'Tháng Hai'
        WHEN 3 THEN N'Tháng Ba'
        WHEN 4 THEN N'Tháng Tư'
        WHEN 5 THEN N'Tháng Năm'
        WHEN 6 THEN N'Tháng Sáu'
        WHEN 7 THEN N'Tháng Bảy'
        WHEN 8 THEN N'Tháng Tám'
        WHEN 9 THEN N'Tháng Chín'
        WHEN 10 THEN N'Tháng Mười'
        WHEN 11 THEN N'Tháng Mười Một'
        WHEN 12 THEN N'Tháng Mười Hai'
        ELSE N'Không hợp lệ'
    END;
END
GO

PRINT N'✓ Function 9: fn_GetMonthNameVietnamese đã tạo thành công.';
GO

-- =============================================
-- FUNCTION 10: fn_CalculateTax (Scalar Function)
-- Loại: Scalar Function
-- Mục đích: Tính thuế VAT (10%) từ giá trị đơn hàng
-- Minh họa: Arithmetic calculation với constant
-- =============================================
IF OBJECT_ID('dbo.fn_CalculateTax', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_CalculateTax;
GO

CREATE FUNCTION fn_CalculateTax
(
    @Amount DECIMAL(18, 2)
)
RETURNS DECIMAL(18, 2)
AS
BEGIN
    DECLARE @TaxRate DECIMAL(5, 2) = 10.0;  -- Thuế VAT 10%
    DECLARE @TaxAmount DECIMAL(18, 2);
    
    -- Tính tiền thuế
    SET @TaxAmount = @Amount * (@TaxRate / 100.0);
    
    RETURN @TaxAmount;
END
GO

PRINT N'✓ Function 10: fn_CalculateTax đã tạo thành công.';
GO

-- =============================================
-- FUNCTION 11: fn_GetProductsInCategory (Table-Valued Function)
-- Loại: Inline Table-Valued Function
-- Mục đích: Lấy danh sách sản phẩm trong 1 danh mục
-- Minh họa: RETURNS TABLE, JOIN nhiều bảng, WHERE filter
-- =============================================
IF OBJECT_ID('dbo.fn_GetProductsInCategory', 'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_GetProductsInCategory;
GO

CREATE FUNCTION fn_GetProductsInCategory
(
    @CategoryId INT
)
RETURNS TABLE
AS
RETURN
(
    -- Trả về bảng kết quả, có thể dùng như 1 view hoặc subquery
    SELECT 
        p.ProductId,
        p.Title,
        p.Author,
        p.Description,
        p.Price,
        p.Stock,
        p.CreatedAt,
        c.Name AS CategoryName
    FROM dbo.Products p
    INNER JOIN dbo.Categories c ON p.CategoryId = c.CategoryId
    WHERE p.CategoryId = @CategoryId
    AND p.IsActive = 1
);
GO

PRINT N'✓ Function 11: fn_GetProductsInCategory đã tạo thành công.';
GO

-- =============================================
-- FUNCTION 12: fn_GetTopSellingProducts (Table-Valued Function)
-- Loại: Inline Table-Valued Function
-- Mục đích: Lấy top sản phẩm bán chạy nhất
-- Minh họa: Aggregation (SUM, GROUP BY), ORDER BY, TOP
-- =============================================
IF OBJECT_ID('dbo.fn_GetTopSellingProducts', 'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_GetTopSellingProducts;
GO

CREATE FUNCTION fn_GetTopSellingProducts
(
    @TopN INT
)
RETURNS TABLE
AS
RETURN
(
    -- Trả về top N sản phẩm bán chạy
    SELECT TOP (@TopN)
        p.ProductId,
        p.Title,
        p.Author,
        p.Price,
        c.Name AS CategoryName,
        SUM(oi.Quantity) AS TotalSold,
        SUM(oi.Quantity * oi.UnitPrice) AS TotalRevenue
    FROM dbo.Products p
    INNER JOIN dbo.OrderItems oi ON p.ProductId = oi.ProductId
    INNER JOIN dbo.Orders o ON oi.OrderId = o.OrderId
    LEFT JOIN dbo.Categories c ON p.CategoryId = c.CategoryId
    WHERE o.PaymentStatus = 'Paid'
    GROUP BY p.ProductId, p.Title, p.Author, p.Price, c.Name
    ORDER BY TotalSold DESC
);
GO

PRINT N'✓ Function 12: fn_GetTopSellingProducts đã tạo thành công.';
GO

-- =============================================
-- FUNCTION 13: fn_GetOrdersByDateRange (Table-Valued Function)
-- Loại: Inline Table-Valued Function
-- Mục đích: Lấy danh sách đơn hàng trong khoảng thời gian
-- Minh họa: Date filtering với BETWEEN, optional parameters
-- =============================================
IF OBJECT_ID('dbo.fn_GetOrdersByDateRange', 'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_GetOrdersByDateRange;
GO

CREATE FUNCTION fn_GetOrdersByDateRange
(
    @StartDate DATE,
    @EndDate DATE
)
RETURNS TABLE
AS
RETURN
(
    -- Lọc đơn hàng theo khoảng ngày
    SELECT 
        o.OrderId,
        o.OrderNumber,
        o.OrderDate,
        o.Total,
        o.OrderStatus,
        o.PaymentStatus,
        u.FullName AS CustomerName,
        u.Email AS CustomerEmail
    FROM dbo.Orders o
    INNER JOIN dbo.AspNetUsers u ON o.UserId = u.Id
    WHERE CAST(o.OrderDate AS DATE) BETWEEN @StartDate AND @EndDate
);
GO

PRINT N'✓ Function 13: fn_GetOrdersByDateRange đã tạo thành công.';
GO

-- =============================================
-- Tổng kết
-- =============================================
PRINT N'';
PRINT N'=============================================';
PRINT N'Đã tạo thành công tất cả 13 functions!';
PRINT N'=============================================';
PRINT N'';
PRINT N'SCALAR FUNCTIONS (10 cái) - Trả về 1 giá trị:';
PRINT N'  1.  fn_CalculateDiscount           - Tính tiền giảm giá';
PRINT N'  2.  fn_CalculateFinalPrice         - Tính giá sau giảm';
PRINT N'  3.  fn_GetUserCartTotal            - Tổng tiền giỏ hàng';
PRINT N'  4.  fn_GetUserCartCount            - Đếm số sản phẩm trong giỏ';
PRINT N'  5.  fn_GetProductAverageRating     - Điểm đánh giá TB';
PRINT N'  6.  fn_GetProductReviewCount       - Đếm số đánh giá';
PRINT N'  7.  fn_FormatVNDCurrency           - Định dạng tiền tệ';
PRINT N'  8.  fn_GetOrderStatusDisplay       - Chuyển status sang TV';
PRINT N'  9.  fn_GetMonthNameVietnamese      - Tên tháng tiếng Việt';
PRINT N'  10. fn_CalculateTax                - Tính thuế VAT';
PRINT N'';
PRINT N'TABLE-VALUED FUNCTIONS (3 cái) - Trả về bảng:';
PRINT N'  11. fn_GetProductsInCategory       - Sản phẩm theo danh mục';
PRINT N'  12. fn_GetTopSellingProducts       - Top bán chạy';
PRINT N'  13. fn_GetOrdersByDateRange        - Đơn hàng theo ngày';
PRINT N'=============================================';
PRINT N'';
PRINT N'LƯU Ý SỬ DỤNG:';
PRINT N'- Scalar Function: SELECT dbo.fn_CalculateDiscount(100000, 20)';
PRINT N'- Table Function:  SELECT * FROM dbo.fn_GetProductsInCategory(1)';
PRINT N'=============================================';
GO
