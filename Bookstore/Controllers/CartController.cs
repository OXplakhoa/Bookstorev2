using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Web.Mvc;
using Bookstore.Models;
using Bookstore.ViewModels;
using Microsoft.AspNet.Identity;

namespace Bookstore.Controllers
{
    /// <summary>
    /// CartController - Manages shopping cart functionality
    /// Uses stored procedures: sp_AddToCart, sp_UpdateCartItemQuantity, sp_ClearUserCart
    /// Uses functions: fn_GetUserCartTotal, fn_GetUserCartCount
    /// </summary>
    [Authorize]
    public class CartController : Controller
    {
        private BookstoreDbEntities db = new BookstoreDbEntities();

        // GET: Cart
        /// <summary>
        /// Display the user's shopping cart with all items
        /// </summary>
        public ActionResult Index()
        {
            var userId = User.Identity.GetUserId();

            // Get cart total using SQL function fn_GetUserCartTotal
            var cartTotal = db.Database.SqlQuery<decimal>(
                "SELECT dbo.fn_GetUserCartTotal(@UserId)",
                new SqlParameter("@UserId", userId)
            ).FirstOrDefault();

            // Get cart count using SQL function fn_GetUserCartCount
            var cartCount = db.Database.SqlQuery<int>(
                "SELECT dbo.fn_GetUserCartCount(@UserId)",
                new SqlParameter("@UserId", userId)
            ).FirstOrDefault();

            // Get cart items with product details
            var cartItems = db.CartItems
                .Where(c => c.UserId == userId)
                .Select(c => new CartItemViewModel
                {
                    CartItemId = c.CartItemId,
                    ProductId = c.ProductId,
                    ProductTitle = c.Products.Title,
                    Author = c.Products.Author,
                    UnitPrice = c.Products.Price,
                    Quantity = c.Quantity,
                    Stock = c.Products.Stock,
                    CategoryName = c.Products.Categories.Name,
                    DateAdded = c.DateAdded,
                    ImageUrl = c.Products.ProductImages
                        .Where(pi => pi.IsMain)
                        .Select(pi => pi.ImageUrl)
                        .FirstOrDefault() ?? "/Content/images/no-image.png"
                })
                .OrderByDescending(c => c.DateAdded)
                .ToList();

            // Calculate tax using SQL function fn_CalculateTax
            var tax = db.Database.SqlQuery<decimal>(
                "SELECT dbo.fn_CalculateTax(@Amount)",
                new SqlParameter("@Amount", cartTotal)
            ).FirstOrDefault();

            // Build the cart view model
            var viewModel = new CartViewModel
            {
                Items = cartItems,
                TotalQuantity = cartCount,
                Subtotal = cartTotal,
                ShippingFee = cartTotal >= 500000 ? 0 : 30000, // Free shipping for orders >= 500,000₫
                Tax = tax
            };

            return View(viewModel);
        }

        // POST: Cart/Add
        /// <summary>
        /// Add a product to cart using stored procedure sp_AddToCart
        /// </summary>
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Add(AddToCartViewModel model)
        {
            if (!ModelState.IsValid)
            {
                return Json(new CartOperationResult
                {
                    Success = false,
                    Message = "Dữ liệu không hợp lệ."
                });
            }

            var userId = User.Identity.GetUserId();

            try
            {
                // Call stored procedure sp_AddToCart
                var result = db.Database.SqlQuery<int>(
                    "EXEC sp_AddToCart @UserId, @ProductId, @Quantity",
                    new SqlParameter("@UserId", userId),
                    new SqlParameter("@ProductId", model.ProductId),
                    new SqlParameter("@Quantity", model.Quantity)
                ).FirstOrDefault();

                // Get updated cart total
                var cartTotal = db.Database.SqlQuery<decimal>(
                    "SELECT dbo.fn_GetUserCartTotal(@UserId)",
                    new SqlParameter("@UserId", userId)
                ).FirstOrDefault();

                return Json(new CartOperationResult
                {
                    Success = true,
                    Message = "Đã thêm sản phẩm vào giỏ hàng!",
                    CartCount = result,
                    CartTotal = cartTotal
                });
            }
            catch (SqlException ex)
            {
                return Json(new CartOperationResult
                {
                    Success = false,
                    Message = ex.Message.Contains("không tồn tại") 
                        ? "Sản phẩm không tồn tại hoặc đã ngừng bán."
                        : ex.Message.Contains("Không đủ hàng")
                            ? "Không đủ hàng trong kho."
                            : "Có lỗi xảy ra. Vui lòng thử lại."
                });
            }
        }

        // POST: Cart/Update
        /// <summary>
        /// Update cart item quantity using stored procedure sp_UpdateCartItemQuantity
        /// </summary>
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Update(UpdateCartItemViewModel model)
        {
            if (!ModelState.IsValid)
            {
                return Json(new CartOperationResult
                {
                    Success = false,
                    Message = "Số lượng không hợp lệ."
                });
            }

            var userId = User.Identity.GetUserId();

            // Verify the cart item belongs to the current user
            var cartItem = db.CartItems.FirstOrDefault(c => c.CartItemId == model.CartItemId && c.UserId == userId);
            if (cartItem == null)
            {
                return Json(new CartOperationResult
                {
                    Success = false,
                    Message = "Không tìm thấy sản phẩm trong giỏ hàng."
                });
            }

            try
            {
                // Call stored procedure sp_UpdateCartItemQuantity
                db.Database.ExecuteSqlCommand(
                    "EXEC sp_UpdateCartItemQuantity @CartItemId, @NewQuantity",
                    new SqlParameter("@CartItemId", model.CartItemId),
                    new SqlParameter("@NewQuantity", model.Quantity)
                );

                // Get updated cart totals
                var cartCount = db.Database.SqlQuery<int>(
                    "SELECT dbo.fn_GetUserCartCount(@UserId)",
                    new SqlParameter("@UserId", userId)
                ).FirstOrDefault();

                var cartTotal = db.Database.SqlQuery<decimal>(
                    "SELECT dbo.fn_GetUserCartTotal(@UserId)",
                    new SqlParameter("@UserId", userId)
                ).FirstOrDefault();

                // Calculate new subtotal for this item
                var product = db.Products.Find(cartItem.ProductId);
                var itemSubtotal = product.Price * model.Quantity;

                return Json(new CartOperationResult
                {
                    Success = true,
                    Message = "Đã cập nhật số lượng!",
                    CartCount = cartCount,
                    CartTotal = cartTotal,
                    Data = new
                    {
                        ItemSubtotal = itemSubtotal,
                        ItemSubtotalFormatted = string.Format("{0:N0}₫", itemSubtotal)
                    }
                });
            }
            catch (SqlException ex)
            {
                return Json(new CartOperationResult
                {
                    Success = false,
                    Message = ex.Message.Contains("lớn hơn 0")
                        ? "Số lượng phải lớn hơn 0."
                        : ex.Message.Contains("vượt quá tồn kho")
                            ? "Số lượng vượt quá tồn kho hiện có."
                            : "Có lỗi xảy ra. Vui lòng thử lại."
                });
            }
        }

        // POST: Cart/Remove
        /// <summary>
        /// Remove a single item from cart
        /// </summary>
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Remove(int cartItemId)
        {
            var userId = User.Identity.GetUserId();

            // Find and verify ownership
            var cartItem = db.CartItems.FirstOrDefault(c => c.CartItemId == cartItemId && c.UserId == userId);
            if (cartItem == null)
            {
                return Json(new CartOperationResult
                {
                    Success = false,
                    Message = "Không tìm thấy sản phẩm trong giỏ hàng."
                });
            }

            // Remove the item
            db.CartItems.Remove(cartItem);
            db.SaveChanges();

            // Get updated cart totals
            var cartCount = db.Database.SqlQuery<int>(
                "SELECT dbo.fn_GetUserCartCount(@UserId)",
                new SqlParameter("@UserId", userId)
            ).FirstOrDefault();

            var cartTotal = db.Database.SqlQuery<decimal>(
                "SELECT dbo.fn_GetUserCartTotal(@UserId)",
                new SqlParameter("@UserId", userId)
            ).FirstOrDefault();

            return Json(new CartOperationResult
            {
                Success = true,
                Message = "Đã xóa sản phẩm khỏi giỏ hàng!",
                CartCount = cartCount,
                CartTotal = cartTotal
            });
        }

        // POST: Cart/Clear
        /// <summary>
        /// Clear all items from cart using stored procedure sp_ClearUserCart
        /// </summary>
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Clear()
        {
            var userId = User.Identity.GetUserId();

            try
            {
                // Call stored procedure sp_ClearUserCart
                var deletedCount = db.Database.SqlQuery<int>(
                    "EXEC sp_ClearUserCart @UserId",
                    new SqlParameter("@UserId", userId)
                ).FirstOrDefault();

                return Json(new CartOperationResult
                {
                    Success = true,
                    Message = $"Đã xóa {deletedCount} sản phẩm khỏi giỏ hàng!",
                    CartCount = 0,
                    CartTotal = 0
                });
            }
            catch (Exception)
            {
                return Json(new CartOperationResult
                {
                    Success = false,
                    Message = "Có lỗi xảy ra. Vui lòng thử lại."
                });
            }
        }

        // GET: Cart/MiniCart
        /// <summary>
        /// Get mini cart data for navbar display
        /// </summary>
        public ActionResult MiniCart()
        {
            var userId = User.Identity.GetUserId();

            if (string.IsNullOrEmpty(userId))
            {
                return PartialView("_MiniCart", new MiniCartViewModel
                {
                    ItemCount = 0,
                    Total = 0
                });
            }

            // Get cart count using SQL function fn_GetUserCartCount
            var cartCount = db.Database.SqlQuery<int>(
                "SELECT dbo.fn_GetUserCartCount(@UserId)",
                new SqlParameter("@UserId", userId)
            ).FirstOrDefault();

            // Get cart total using SQL function fn_GetUserCartTotal
            var cartTotal = db.Database.SqlQuery<decimal>(
                "SELECT dbo.fn_GetUserCartTotal(@UserId)",
                new SqlParameter("@UserId", userId)
            ).FirstOrDefault();

            var model = new MiniCartViewModel
            {
                ItemCount = cartCount,
                Total = cartTotal
            };

            return PartialView("_MiniCart", model);
        }

        // GET: Cart/GetCartCount
        /// <summary>
        /// API endpoint to get current cart count (for AJAX updates)
        /// </summary>
        public JsonResult GetCartCount()
        {
            var userId = User.Identity.GetUserId();

            if (string.IsNullOrEmpty(userId))
            {
                return Json(new { count = 0, total = 0m }, JsonRequestBehavior.AllowGet);
            }

            var cartCount = db.Database.SqlQuery<int>(
                "SELECT dbo.fn_GetUserCartCount(@UserId)",
                new SqlParameter("@UserId", userId)
            ).FirstOrDefault();

            var cartTotal = db.Database.SqlQuery<decimal>(
                "SELECT dbo.fn_GetUserCartTotal(@UserId)",
                new SqlParameter("@UserId", userId)
            ).FirstOrDefault();

            return Json(new
            {
                count = cartCount,
                total = cartTotal,
                totalFormatted = string.Format("{0:N0}₫", cartTotal)
            }, JsonRequestBehavior.AllowGet);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                db.Dispose();
            }
            base.Dispose(disposing);
        }
    }
}
