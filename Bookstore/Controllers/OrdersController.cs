using System;
using System.Collections.Generic;
using System.Data;
using System.Data.Entity;
using System.Data.SqlClient;
using System.Linq;
using System.Web.Mvc;
using Bookstore.Models;
using Bookstore.ViewModels;
using Microsoft.AspNet.Identity;

namespace Bookstore.Controllers
{
    /// <summary>
    /// OrdersController - Manages order placement and history
    /// Uses stored procedures: sp_CreateOrder, sp_GetUserOrders, sp_GetOrderDetails
    /// Triggers fire automatically for notifications when orders are created/updated
    /// </summary>
    [Authorize]
    public class OrdersController : Controller
    {
        private BookstoreDbEntities db = new BookstoreDbEntities();

        #region Order History

        // GET: Orders
        /// <summary>
        /// Display the user's order history with optional status filter and pagination
        /// Uses stored procedure sp_GetUserOrders
        /// </summary>
        public ActionResult Index(string status = null, int page = 1)
        {
            var userId = User.Identity.GetUserId();
            int pageSize = 10;

            // Get orders using stored procedure sp_GetUserOrders
            var orders = db.Database.SqlQuery<OrderSummaryViewModel>(
                "EXEC sp_GetUserOrders @UserId, @Status, @PageNumber, @PageSize",
                new SqlParameter("@UserId", userId),
                new SqlParameter("@Status", (object)status ?? DBNull.Value),
                new SqlParameter("@PageNumber", page),
                new SqlParameter("@PageSize", pageSize)
            ).ToList();

            // Fix null image URLs
            foreach (var order in orders)
            {
                if (string.IsNullOrEmpty(order.FirstProductImage))
                {
                    order.FirstProductImage = "/Content/images/no-image.png";
                }
            }

            // Get total count for pagination
            var totalOrders = db.Orders.Count(o => o.UserId == userId && 
                (status == null || o.OrderStatus == status));

            var viewModel = new OrderListViewModel
            {
                Orders = orders,
                CurrentStatus = status,
                CurrentPage = page,
                PageSize = pageSize,
                TotalOrders = totalOrders
            };

            return View(viewModel);
        }

        // GET: Orders/Details/5
        /// <summary>
        /// Display order details
        /// Uses stored procedure sp_GetOrderDetails which returns 3 result sets
        /// </summary>
        public ActionResult Details(int id)
        {
            var userId = User.Identity.GetUserId();

            // Verify the order belongs to the current user (security check)
            var orderExists = db.Orders.Any(o => o.OrderId == id && o.UserId == userId);
            if (!orderExists)
            {
                TempData["Error"] = "Không tìm thấy đơn hàng.";
                return RedirectToAction("Index");
            }

            // Get order details using sp_GetOrderDetails
            // This SP returns 3 result sets: Order info, Order items, Payments
            var viewModel = GetOrderDetailsFromStoredProcedure(id);

            if (viewModel.Order == null)
            {
                TempData["Error"] = "Không tìm thấy đơn hàng.";
                return RedirectToAction("Index");
            }

            return View(viewModel);
        }

        #endregion

        #region Checkout & Place Order

        // GET: Orders/Checkout
        /// <summary>
        /// Display checkout page with cart summary and shipping form
        /// Pre-fills user information if available
        /// </summary>
        public ActionResult Checkout()
        {
            var userId = User.Identity.GetUserId();

            // Check if cart has items
            var cartCount = db.Database.SqlQuery<int>(
                "SELECT dbo.fn_GetUserCartCount(@UserId)",
                new SqlParameter("@UserId", userId)
            ).FirstOrDefault();

            if (cartCount == 0)
            {
                TempData["Error"] = "Giỏ hàng của bạn đang trống.";
                return RedirectToAction("Index", "Cart");
            }

            // Get cart data for display
            var cartTotal = db.Database.SqlQuery<decimal>(
                "SELECT dbo.fn_GetUserCartTotal(@UserId)",
                new SqlParameter("@UserId", userId)
            ).FirstOrDefault();

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
                    ImageUrl = c.Products.ProductImages
                        .Where(pi => pi.IsMain)
                        .Select(pi => pi.ImageUrl)
                        .FirstOrDefault() ?? "/Content/images/no-image.png"
                })
                .ToList();

            var tax = db.Database.SqlQuery<decimal>(
                "SELECT dbo.fn_CalculateTax(@Amount)",
                new SqlParameter("@Amount", cartTotal)
            ).FirstOrDefault();

            // Get current user info to pre-fill form
            var user = db.AspNetUsers.Find(userId);

            var viewModel = new PlaceOrderViewModel
            {
                ShippingName = user?.FullName,
                ShippingPhone = user?.PhoneNumber,
                ShippingEmail = user?.Email,
                ShippingAddress = user?.Address,
                Cart = new CartViewModel
                {
                    Items = cartItems,
                    TotalQuantity = cartCount,
                    Subtotal = cartTotal,
                    ShippingFee = cartTotal >= 500000 ? 0 : 30000,
                    Tax = tax
                }
            };

            return View(viewModel);
        }

        // POST: Orders/PlaceOrder
        /// <summary>
        /// Process order placement using stored procedure sp_CreateOrder
        /// The SP handles transaction, stock validation, and cart clearing
        /// Triggers automatically create notifications
        /// </summary>
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult PlaceOrder(PlaceOrderViewModel model)
        {
            var userId = User.Identity.GetUserId();

            // Re-validate cart before proceeding
            var cartCount = db.Database.SqlQuery<int>(
                "SELECT dbo.fn_GetUserCartCount(@UserId)",
                new SqlParameter("@UserId", userId)
            ).FirstOrDefault();

            if (cartCount == 0)
            {
                return Json(new OrderOperationResult
                {
                    Success = false,
                    Message = "Giỏ hàng của bạn đang trống."
                });
            }

            if (!ModelState.IsValid)
            {
                var errors = ModelState.Values
                    .SelectMany(v => v.Errors)
                    .Select(e => e.ErrorMessage)
                    .ToList();
                return Json(new OrderOperationResult
                {
                    Success = false,
                    Message = string.Join(" ", errors)
                });
            }

            try
            {
                // Prepare OUTPUT parameter to receive the new OrderId
                var orderIdParam = new SqlParameter("@OrderId", SqlDbType.Int)
                {
                    Direction = ParameterDirection.Output
                };

                // Call stored procedure sp_CreateOrder
                // This SP:
                // 1. Validates cart is not empty
                // 2. Validates stock availability
                // 3. Creates the order with items
                // 4. Decreases product stock
                // 5. Clears the cart
                // All within a transaction
                db.Database.ExecuteSqlCommand(
                    "EXEC sp_CreateOrder @UserId, @ShippingName, @ShippingPhone, @ShippingEmail, @ShippingAddress, @PaymentMethod, @Notes, @OrderId OUTPUT",
                    new SqlParameter("@UserId", userId),
                    new SqlParameter("@ShippingName", model.ShippingName),
                    new SqlParameter("@ShippingPhone", model.ShippingPhone),
                    new SqlParameter("@ShippingEmail", model.ShippingEmail),
                    new SqlParameter("@ShippingAddress", model.ShippingAddress),
                    new SqlParameter("@PaymentMethod", model.PaymentMethod),
                    new SqlParameter("@Notes", (object)model.Notes ?? DBNull.Value),
                    orderIdParam
                );

                var orderId = (int)orderIdParam.Value;

                // Get the order number for display
                var orderNumber = db.Orders
                    .Where(o => o.OrderId == orderId)
                    .Select(o => o.OrderNumber)
                    .FirstOrDefault();

                // For COD orders, redirect to confirmation
                // For Stripe orders, redirect to payment (CheckoutController will handle this later)
                if (model.PaymentMethod == "COD")
                {
                    return Json(new OrderOperationResult
                    {
                        Success = true,
                        Message = "Đặt hàng thành công!",
                        OrderId = orderId,
                        OrderNumber = orderNumber
                    });
                }
                else if (model.PaymentMethod == "Stripe")
                {
                    // Redirect to Stripe payment (to be implemented in CheckoutController)
                    return Json(new OrderOperationResult
                    {
                        Success = true,
                        Message = "Chuyển đến trang thanh toán...",
                        OrderId = orderId,
                        OrderNumber = orderNumber
                    });
                }

                return Json(new OrderOperationResult
                {
                    Success = true,
                    Message = "Đặt hàng thành công!",
                    OrderId = orderId,
                    OrderNumber = orderNumber
                });
            }
            catch (SqlException ex)
            {
                // Handle specific error messages from the stored procedure
                string message = "Có lỗi xảy ra khi đặt hàng.";

                if (ex.Message.Contains("Giỏ hàng trống"))
                {
                    message = "Giỏ hàng của bạn đang trống.";
                }
                else if (ex.Message.Contains("không đủ số lượng"))
                {
                    message = "Một hoặc nhiều sản phẩm không đủ số lượng trong kho.";
                }

                return Json(new OrderOperationResult
                {
                    Success = false,
                    Message = message
                });
            }
            catch (Exception)
            {
                return Json(new OrderOperationResult
                {
                    Success = false,
                    Message = "Có lỗi xảy ra. Vui lòng thử lại."
                });
            }
        }

        // GET: Orders/Confirmation/5
        /// <summary>
        /// Display order confirmation page after successful order
        /// </summary>
        public ActionResult Confirmation(int id)
        {
            var userId = User.Identity.GetUserId();

            // Verify the order belongs to the current user
            var order = db.Orders.FirstOrDefault(o => o.OrderId == id && o.UserId == userId);
            if (order == null)
            {
                TempData["Error"] = "Không tìm thấy đơn hàng.";
                return RedirectToAction("Index");
            }

            // Get full order details
            var viewModel = GetOrderDetailsFromStoredProcedure(id);

            return View(viewModel);
        }

        #endregion

        #region Order Actions

        // POST: Orders/Cancel/5
        /// <summary>
        /// Cancel an order (only Pending orders can be cancelled)
        /// </summary>
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Cancel(int id)
        {
            var userId = User.Identity.GetUserId();

            var order = db.Orders
                .Include("OrderItems")
                .FirstOrDefault(o => o.OrderId == id && o.UserId == userId);
            if (order == null)
            {
                return Json(new OrderOperationResult
                {
                    Success = false,
                    Message = "Không tìm thấy đơn hàng."
                });
            }

            // Only allow cancellation of Pending orders
            if (order.OrderStatus != "Pending")
            {
                return Json(new OrderOperationResult
                {
                    Success = false,
                    Message = "Chỉ có thể hủy đơn hàng đang chờ xử lý."
                });
            }

            try
            {
                // Update order status to Cancelled
                order.OrderStatus = "Cancelled";

                // Restore product stock
                foreach (var item in order.OrderItems)
                {
                    var product = db.Products.Find(item.ProductId);
                    if (product != null)
                    {
                        product.Stock += item.Quantity;
                    }
                }

                db.SaveChanges();

                return Json(new OrderOperationResult
                {
                    Success = true,
                    Message = "Đơn hàng đã được hủy thành công."
                });
            }
            catch (Exception)
            {
                return Json(new OrderOperationResult
                {
                    Success = false,
                    Message = "Có lỗi xảy ra. Vui lòng thử lại."
                });
            }
        }

        // POST: Orders/Reorder/5
        /// <summary>
        /// Add all items from a previous order back to cart
        /// </summary>
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Reorder(int id)
        {
            var userId = User.Identity.GetUserId();

            var order = db.Orders
                .Include("OrderItems")
                .FirstOrDefault(o => o.OrderId == id && o.UserId == userId);

            if (order == null)
            {
                return Json(new OrderOperationResult
                {
                    Success = false,
                    Message = "Không tìm thấy đơn hàng."
                });
            }

            try
            {
                int addedCount = 0;
                var messages = new List<string>();

                foreach (var item in order.OrderItems)
                {
                    try
                    {
                        // Try to add each item to cart using sp_AddToCart
                        db.Database.ExecuteSqlCommand(
                            "EXEC sp_AddToCart @UserId, @ProductId, @Quantity",
                            new SqlParameter("@UserId", userId),
                            new SqlParameter("@ProductId", item.ProductId),
                            new SqlParameter("@Quantity", item.Quantity)
                        );
                        addedCount++;
                    }
                    catch (SqlException)
                    {
                        // Product may be out of stock or inactive
                        var product = db.Products.Find(item.ProductId);
                        if (product != null)
                        {
                            messages.Add($"'{product.Title}' không còn hàng hoặc không đủ số lượng.");
                        }
                    }
                }

                if (addedCount == 0)
                {
                    return Json(new OrderOperationResult
                    {
                        Success = false,
                        Message = "Không thể thêm sản phẩm vào giỏ hàng. " + string.Join(" ", messages)
                    });
                }

                var resultMessage = $"Đã thêm {addedCount} sản phẩm vào giỏ hàng.";
                if (messages.Any())
                {
                    resultMessage += " " + string.Join(" ", messages);
                }

                return Json(new OrderOperationResult
                {
                    Success = true,
                    Message = resultMessage
                });
            }
            catch (Exception)
            {
                return Json(new OrderOperationResult
                {
                    Success = false,
                    Message = "Có lỗi xảy ra. Vui lòng thử lại."
                });
            }
        }

        #endregion

        #region Helper Methods

        /// <summary>
        /// Get order details using sp_GetOrderDetails stored procedure
        /// Handles multiple result sets
        /// </summary>
        private OrderDetailsViewModel GetOrderDetailsFromStoredProcedure(int orderId)
        {
            var viewModel = new OrderDetailsViewModel();

            using (var conn = new SqlConnection(db.Database.Connection.ConnectionString))
            {
                using (var cmd = new SqlCommand("sp_GetOrderDetails", conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@OrderId", orderId);

                    conn.Open();

                    using (var reader = cmd.ExecuteReader())
                    {
                        // Result set 1: Order info
                        if (reader.Read())
                        {
                            viewModel.Order = new OrderInfoViewModel
                            {
                                OrderId = reader.GetInt32(reader.GetOrdinal("OrderId")),
                                OrderNumber = reader.IsDBNull(reader.GetOrdinal("OrderNumber")) ? null : reader.GetString(reader.GetOrdinal("OrderNumber")),
                                OrderDate = reader.GetDateTime(reader.GetOrdinal("OrderDate")),
                                Total = reader.GetDecimal(reader.GetOrdinal("Total")),
                                OrderStatus = reader.IsDBNull(reader.GetOrdinal("OrderStatus")) ? null : reader.GetString(reader.GetOrdinal("OrderStatus")),
                                PaymentMethod = reader.IsDBNull(reader.GetOrdinal("PaymentMethod")) ? null : reader.GetString(reader.GetOrdinal("PaymentMethod")),
                                PaymentStatus = reader.IsDBNull(reader.GetOrdinal("PaymentStatus")) ? null : reader.GetString(reader.GetOrdinal("PaymentStatus")),
                                ShippingName = reader.IsDBNull(reader.GetOrdinal("ShippingName")) ? null : reader.GetString(reader.GetOrdinal("ShippingName")),
                                ShippingPhone = reader.IsDBNull(reader.GetOrdinal("ShippingPhone")) ? null : reader.GetString(reader.GetOrdinal("ShippingPhone")),
                                ShippingEmail = reader.IsDBNull(reader.GetOrdinal("ShippingEmail")) ? null : reader.GetString(reader.GetOrdinal("ShippingEmail")),
                                ShippingAddress = reader.IsDBNull(reader.GetOrdinal("ShippingAddress")) ? null : reader.GetString(reader.GetOrdinal("ShippingAddress")),
                                TrackingNumber = reader.IsDBNull(reader.GetOrdinal("TrackingNumber")) ? null : reader.GetString(reader.GetOrdinal("TrackingNumber")),
                                Notes = reader.IsDBNull(reader.GetOrdinal("Notes")) ? null : reader.GetString(reader.GetOrdinal("Notes")),
                                CustomerEmail = reader.IsDBNull(reader.GetOrdinal("CustomerEmail")) ? null : reader.GetString(reader.GetOrdinal("CustomerEmail")),
                                CustomerName = reader.IsDBNull(reader.GetOrdinal("CustomerName")) ? null : reader.GetString(reader.GetOrdinal("CustomerName"))
                            };
                        }

                        // Result set 2: Order items
                        if (reader.NextResult())
                        {
                            while (reader.Read())
                            {
                                viewModel.Items.Add(new OrderItemViewModel
                                {
                                    OrderItemId = reader.GetInt32(reader.GetOrdinal("OrderItemId")),
                                    ProductId = reader.GetInt32(reader.GetOrdinal("ProductId")),
                                    Quantity = reader.GetInt32(reader.GetOrdinal("Quantity")),
                                    UnitPrice = reader.GetDecimal(reader.GetOrdinal("UnitPrice")),
                                    ProductTitle = reader.IsDBNull(reader.GetOrdinal("ProductTitle")) ? null : reader.GetString(reader.GetOrdinal("ProductTitle")),
                                    ProductAuthor = reader.IsDBNull(reader.GetOrdinal("ProductAuthor")) ? null : reader.GetString(reader.GetOrdinal("ProductAuthor")),
                                    ProductImageUrl = reader.IsDBNull(reader.GetOrdinal("ProductImageUrl")) ? "/Content/images/no-image.png" : reader.GetString(reader.GetOrdinal("ProductImageUrl")),
                                    Subtotal = reader.GetDecimal(reader.GetOrdinal("Subtotal"))
                                });
                            }
                        }

                        // Result set 3: Payment history
                        if (reader.NextResult())
                        {
                            while (reader.Read())
                            {
                                viewModel.Payments.Add(new PaymentHistoryViewModel
                                {
                                    PaymentId = reader.GetInt32(reader.GetOrdinal("PaymentId")),
                                    PaymentMethod = reader.IsDBNull(reader.GetOrdinal("PaymentMethod")) ? null : reader.GetString(reader.GetOrdinal("PaymentMethod")),
                                    Status = reader.IsDBNull(reader.GetOrdinal("Status")) ? null : reader.GetString(reader.GetOrdinal("Status")),
                                    PaymentDate = reader.GetDateTime(reader.GetOrdinal("PaymentDate")),
                                    Amount = reader.GetDecimal(reader.GetOrdinal("Amount")),
                                    TransactionId = reader.IsDBNull(reader.GetOrdinal("TransactionId")) ? null : reader.GetString(reader.GetOrdinal("TransactionId"))
                                });
                            }
                        }
                    }
                }
            }

            return viewModel;
        }

        #endregion

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
