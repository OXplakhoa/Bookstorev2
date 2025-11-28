-- Bookstore Database Schema
-- SQL Server Create Table Script
-- Generated: 2025-11-27

-- =============================================
-- ASP.NET Identity Tables
-- =============================================

CREATE TABLE AspNetUsers (
    Id NVARCHAR(450) PRIMARY KEY,
    FullName NVARCHAR(100),
    DateOfBirth DATETIME2,
    Address NVARCHAR(500),
    ProfilePictureUrl NVARCHAR(500),
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    IsDeleted BIT NOT NULL DEFAULT 0, 
    UserName NVARCHAR(256),
    NormalizedUserName NVARCHAR(256),
    Email NVARCHAR(256),
    NormalizedEmail NVARCHAR(256),
    EmailConfirmed BIT NOT NULL,
    PasswordHash NVARCHAR(MAX),
    SecurityStamp NVARCHAR(MAX),
    ConcurrencyStamp NVARCHAR(MAX),
    PhoneNumber NVARCHAR(MAX),
    PhoneNumberConfirmed BIT NOT NULL,
    TwoFactorEnabled BIT NOT NULL,
    LockoutEnd DATETIMEOFFSET,
    LockoutEnabled BIT NOT NULL,
    AccessFailedCount INT NOT NULL
);

CREATE TABLE AspNetRoles (
    Id NVARCHAR(450) PRIMARY KEY,
    Name NVARCHAR(256),
    NormalizedName NVARCHAR(256),
    ConcurrencyStamp NVARCHAR(MAX)
);

CREATE TABLE AspNetUserRoles (
    UserId NVARCHAR(450) NOT NULL,
    RoleId NVARCHAR(450) NOT NULL,
    PRIMARY KEY (UserId, RoleId),
    FOREIGN KEY (UserId) REFERENCES AspNetUsers(Id) ON DELETE CASCADE,
    FOREIGN KEY (RoleId) REFERENCES AspNetRoles(Id) ON DELETE CASCADE
);

CREATE TABLE AspNetUserClaims (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    UserId NVARCHAR(450) NOT NULL,
    ClaimType NVARCHAR(MAX),
    ClaimValue NVARCHAR(MAX),
    FOREIGN KEY (UserId) REFERENCES AspNetUsers(Id) ON DELETE CASCADE
);

CREATE TABLE AspNetUserLogins (
    LoginProvider NVARCHAR(450) NOT NULL,
    ProviderKey NVARCHAR(450) NOT NULL,
    ProviderDisplayName NVARCHAR(MAX),
    UserId NVARCHAR(450) NOT NULL,
    PRIMARY KEY (LoginProvider, ProviderKey),
    FOREIGN KEY (UserId) REFERENCES AspNetUsers(Id) ON DELETE CASCADE
);

CREATE TABLE AspNetUserTokens (
    UserId NVARCHAR(450) NOT NULL,
    LoginProvider NVARCHAR(450) NOT NULL,
    Name NVARCHAR(450) NOT NULL,
    Value NVARCHAR(MAX),
    PRIMARY KEY (UserId, LoginProvider, Name),
    FOREIGN KEY (UserId) REFERENCES AspNetUsers(Id) ON DELETE CASCADE
);

CREATE TABLE AspNetRoleClaims (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    RoleId NVARCHAR(450) NOT NULL,
    ClaimType NVARCHAR(MAX),
    ClaimValue NVARCHAR(MAX),
    FOREIGN KEY (RoleId) REFERENCES AspNetRoles(Id) ON DELETE CASCADE
);

-- =============================================
-- Bảng phụ
-- =============================================

CREATE TABLE Categories (
    CategoryId INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(100) NOT NULL,
    Slug NVARCHAR(100) NOT NULL,
    Description NVARCHAR(500)
);

CREATE TABLE Products (
    ProductId INT IDENTITY(1,1) PRIMARY KEY,
    Title NVARCHAR(200) NOT NULL,
    Author NVARCHAR(100) NOT NULL,
    Description NVARCHAR(MAX),
    Price DECIMAL(18,2) NOT NULL,
    Stock INT NOT NULL,
    CategoryId INT,
    IsActive BIT NOT NULL,
    CreatedAt DATETIME2 NOT NULL,
    FOREIGN KEY (CategoryId) REFERENCES Categories(CategoryId) ON DELETE CASCADE
);

CREATE TABLE ProductImages (
    ProductImageId INT IDENTITY(1,1) PRIMARY KEY,
    ProductId INT NOT NULL,
    ImageUrl NVARCHAR(500) NOT NULL,
    IsMain BIT NOT NULL,
    FOREIGN KEY (ProductId) REFERENCES Products(ProductId) ON DELETE CASCADE
);

CREATE TABLE FlashSales (
    FlashSaleId INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(200) NOT NULL,
    Description NVARCHAR(1000),
    StartDate DATETIME2 NOT NULL,
    EndDate DATETIME2 NOT NULL,
    IsActive BIT NOT NULL,
    CreatedAt DATETIME2 NOT NULL
);

CREATE TABLE FlashSaleProducts (
    FlashSaleProductId INT IDENTITY(1,1) PRIMARY KEY,
    FlashSaleId INT NOT NULL,
    ProductId INT NOT NULL,
    OriginalPrice DECIMAL(18,2) NOT NULL,
    SalePrice DECIMAL(18,2) NOT NULL,
    DiscountPercentage DECIMAL(5,2) NOT NULL,
    StockLimit INT,
    SoldCount INT NOT NULL,
    FOREIGN KEY (FlashSaleId) REFERENCES FlashSales(FlashSaleId) ON DELETE CASCADE,
    FOREIGN KEY (ProductId) REFERENCES Products(ProductId) ON DELETE CASCADE
);

CREATE TABLE Orders (
    OrderId INT IDENTITY(1,1) PRIMARY KEY,
    UserId NVARCHAR(450) NOT NULL,
    OrderNumber NVARCHAR(50) NOT NULL,
    OrderDate DATETIME2 NOT NULL,
    Total DECIMAL(18,2) NOT NULL,
    OrderStatus NVARCHAR(50) NOT NULL,
    PaymentStatus NVARCHAR(50) NOT NULL,
    PaymentMethod NVARCHAR(50),
    ShippingName NVARCHAR(100) NOT NULL,
    ShippingEmail NVARCHAR(100) NOT NULL,
    ShippingPhone NVARCHAR(20) NOT NULL,
    ShippingAddress NVARCHAR(500) NOT NULL,
    TrackingNumber NVARCHAR(100),
    Notes NVARCHAR(500),
    FOREIGN KEY (UserId) REFERENCES AspNetUsers(Id) ON DELETE CASCADE
);

CREATE TABLE OrderItems (
    OrderItemId INT IDENTITY(1,1) PRIMARY KEY,
    OrderId INT NOT NULL,
    ProductId INT NOT NULL,
    FlashSaleProductId INT,
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(18,2) NOT NULL,
    WasOnFlashSale BIT NOT NULL,
    FlashSaleDiscount DECIMAL(18,2),
    FOREIGN KEY (OrderId) REFERENCES Orders(OrderId) ON DELETE CASCADE,
    FOREIGN KEY (ProductId) REFERENCES Products(ProductId) ON DELETE CASCADE,
    FOREIGN KEY (FlashSaleProductId) REFERENCES FlashSaleProducts(FlashSaleProductId)
);

CREATE TABLE CartItems (
    CartItemId INT IDENTITY(1,1) PRIMARY KEY,
    UserId NVARCHAR(450) NOT NULL,
    ProductId INT NOT NULL,
    FlashSaleProductId INT,
    Quantity INT NOT NULL,
    DateAdded DATETIME2 NOT NULL,
    LockedPrice DECIMAL(18,2),
    FOREIGN KEY (UserId) REFERENCES AspNetUsers(Id) ON DELETE CASCADE,
    FOREIGN KEY (ProductId) REFERENCES Products(ProductId) ON DELETE CASCADE,
    FOREIGN KEY (FlashSaleProductId) REFERENCES FlashSaleProducts(FlashSaleProductId)
);

CREATE TABLE Payments (
    PaymentId INT IDENTITY(1,1) PRIMARY KEY,
    OrderId INT NOT NULL,
    PaymentMethod NVARCHAR(50) NOT NULL,
    Status NVARCHAR(50) NOT NULL,
    PaymentDate DATETIME2 NOT NULL,
    Amount DECIMAL(18,2) NOT NULL,
    TransactionId NVARCHAR(100),
    PaymentIntentId NVARCHAR(100),
    FOREIGN KEY (OrderId) REFERENCES Orders(OrderId) ON DELETE CASCADE
);

CREATE TABLE Reviews (
    ReviewId INT IDENTITY(1,1) PRIMARY KEY,
    UserId NVARCHAR(450) NOT NULL,
    ProductId INT NOT NULL,
    Rating INT NOT NULL,
    Comment NVARCHAR(1000),
    CreatedAt DATETIME2 NOT NULL,
    FOREIGN KEY (ProductId) REFERENCES Products(ProductId) ON DELETE CASCADE
);

CREATE TABLE FavoriteProducts (
    ApplicationUserId NVARCHAR(450) NOT NULL,
    ProductId INT NOT NULL,
    PRIMARY KEY (ApplicationUserId, ProductId),
    FOREIGN KEY (ApplicationUserId) REFERENCES AspNetUsers(Id) ON DELETE CASCADE,
    FOREIGN KEY (ProductId) REFERENCES Products(ProductId) ON DELETE CASCADE
);

CREATE TABLE RecentlyViewedProducts (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    ApplicationUserId NVARCHAR(450) NOT NULL,
    ProductId INT NOT NULL,
    ViewedAt DATETIME2 NOT NULL,
    FOREIGN KEY (ApplicationUserId) REFERENCES AspNetUsers(Id) ON DELETE CASCADE,
    FOREIGN KEY (ProductId) REFERENCES Products(ProductId) ON DELETE CASCADE
);

CREATE TABLE Notifications (
    NotificationId INT IDENTITY(1,1) PRIMARY KEY,
    UserId NVARCHAR(450) NOT NULL,
    Message NVARCHAR(500) NOT NULL,
    CreatedAt DATETIME2 NOT NULL
);

CREATE TABLE Messages (
    MessageId INT IDENTITY(1,1) PRIMARY KEY,
    SenderId NVARCHAR(450) NOT NULL,
    ReceiverId NVARCHAR(450) NOT NULL,
    Content NVARCHAR(1000) NOT NULL,
    CreatedAt DATETIME2 NOT NULL
);
