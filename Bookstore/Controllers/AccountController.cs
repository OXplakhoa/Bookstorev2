using System;
using System.Data.SqlClient;
using System.Linq;
using System.Security.Claims;
using System.Web;
using System.Web.Mvc;
using Bookstore.Models;
using Bookstore.ViewModels;
using Microsoft.AspNet.Identity;
using Microsoft.Owin.Security;

namespace Bookstore.Controllers
{
    public class AccountController : Controller
    {
        private BookstoreDbEntities db = new BookstoreDbEntities();

        private IAuthenticationManager AuthenticationManager
        {
            get { return HttpContext.GetOwinContext().Authentication; }
        }

        // GET: /Account/Login
        [AllowAnonymous]
        public ActionResult Login(string returnUrl)
        {
            if (User.Identity.IsAuthenticated)
            {
                return RedirectToAction("Index", "Home");
            }
            ViewBag.ReturnUrl = returnUrl;
            return View();
        }

        // POST: /Account/Login
        [HttpPost]
        [AllowAnonymous]
        [ValidateAntiForgeryToken]
        public ActionResult Login(LoginViewModel model, string returnUrl)
        {
            if (!ModelState.IsValid)
            {
                return View(model);
            }

            // Find user by email
            var user = db.AspNetUsers.FirstOrDefault(u => u.Email == model.Email);

            if (user == null)
            {
                ModelState.AddModelError("", "Invalid email or password.");
                return View(model);
            }

            // Check if user is active
            if (!user.IsActive)
            {
                ModelState.AddModelError("", "Your account has been deactivated. Please contact support.");
                return View(model);
            }

            // Check if user is locked out
            if (user.LockoutEnd.HasValue && user.LockoutEnd.Value > DateTimeOffset.UtcNow)
            {
                ModelState.AddModelError("", "Your account is locked. Please try again later.");
                return View(model);
            }

            // Verify password using ASP.NET Identity's password hasher
            var passwordHasher = new Microsoft.AspNet.Identity.PasswordHasher();
            var result = passwordHasher.VerifyHashedPassword(user.PasswordHash, model.Password);

            if (result == PasswordVerificationResult.Failed)
            {
                // Increment failed login count
                user.AccessFailedCount++;
                if (user.AccessFailedCount >= 5)
                {
                    user.LockoutEnd = DateTimeOffset.UtcNow.AddMinutes(15);
                }
                db.SaveChanges();

                ModelState.AddModelError("", "Invalid email or password.");
                return View(model);
            }

            // Reset failed login count on successful login
            user.AccessFailedCount = 0;
            user.LockoutEnd = null;
            db.SaveChanges();

            // Get user's role
            var userRole = user.AspNetRoles.FirstOrDefault();
            string roleName = userRole?.Name ?? "Customer";

            // Create claims identity
            var claims = new[]
            {
                new Claim(ClaimTypes.NameIdentifier, user.Id),
                new Claim(ClaimTypes.Name, user.Email),
                new Claim(ClaimTypes.Email, user.Email),
                new Claim(ClaimTypes.GivenName, user.FullName ?? user.Email),
                new Claim(ClaimTypes.Role, roleName)
            };

            var identity = new ClaimsIdentity(claims, DefaultAuthenticationTypes.ApplicationCookie);

            AuthenticationManager.SignIn(new AuthenticationProperties
            {
                IsPersistent = model.RememberMe,
                ExpiresUtc = model.RememberMe ? DateTimeOffset.UtcNow.AddDays(7) : DateTimeOffset.UtcNow.AddHours(2)
            }, identity);

            // Redirect based on role
            if (!string.IsNullOrEmpty(returnUrl) && Url.IsLocalUrl(returnUrl))
            {
                return Redirect(returnUrl);
            }

            if (roleName == "Admin")
            {
                return RedirectToAction("Index", "Admin");
            }

            return RedirectToAction("Index", "Home");
        }

        // GET: /Account/Register
        [AllowAnonymous]
        public ActionResult Register()
        {
            if (User.Identity.IsAuthenticated)
            {
                return RedirectToAction("Index", "Home");
            }
            return View();
        }

        // POST: /Account/Register
        [HttpPost]
        [AllowAnonymous]
        [ValidateAntiForgeryToken]
        public ActionResult Register(RegisterViewModel model)
        {
            if (!ModelState.IsValid)
            {
                return View(model);
            }

            // Check if email already exists
            if (db.AspNetUsers.Any(u => u.Email == model.Email))
            {
                ModelState.AddModelError("Email", "This email is already registered.");
                return View(model);
            }

            // Hash the password
            var passwordHasher = new Microsoft.AspNet.Identity.PasswordHasher();
            string hashedPassword = passwordHasher.HashPassword(model.Password);

            // Create new user
            var userId = Guid.NewGuid().ToString();
            var user = new AspNetUsers
            {
                Id = userId,
                Email = model.Email,
                NormalizedEmail = model.Email.ToUpper(),
                UserName = model.Email,
                NormalizedUserName = model.Email.ToUpper(),
                FullName = model.FullName,
                PhoneNumber = model.PhoneNumber,
                DateOfBirth = model.DateOfBirth ?? DateTime.Today.AddYears(-18),
                Address = model.Address ?? "",
                PasswordHash = hashedPassword,
                SecurityStamp = Guid.NewGuid().ToString(),
                ConcurrencyStamp = Guid.NewGuid().ToString(),
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                IsActive = true,
                IsDeleted = false,
                EmailConfirmed = true, // Auto-confirm for demo purposes
                PhoneNumberConfirmed = false,
                TwoFactorEnabled = false,
                LockoutEnabled = true,
                AccessFailedCount = 0
            };

            // Get Customer role
            var customerRole = db.AspNetRoles.FirstOrDefault(r => r.Name == "Customer");
            if (customerRole != null)
            {
                user.AspNetRoles.Add(customerRole);
            }

            db.AspNetUsers.Add(user);
            db.SaveChanges();

            TempData["SuccessMessage"] = "Registration successful! Please log in.";
            return RedirectToAction("Login");
        }

        // POST: /Account/Logout
        [HttpPost]
        [ValidateAntiForgeryToken]
        [ActionName("Logout")]
        public ActionResult LogoutPost()
        {
            AuthenticationManager.SignOut(DefaultAuthenticationTypes.ApplicationCookie);
            return RedirectToAction("Index", "Home");
        }

        // GET: /Account/Logout (for convenience - allows direct URL access)
        [HttpGet]
        public ActionResult Logout()
        {
            AuthenticationManager.SignOut(DefaultAuthenticationTypes.ApplicationCookie);
            return RedirectToAction("Index", "Home");
        }

        // GET: /Account/Profile
        [Authorize]
        public ActionResult Profile()
        {
            var userId = User.Identity.GetUserId();
            var user = db.AspNetUsers.Find(userId);

            if (user == null)
            {
                return HttpNotFound();
            }

            // Get user's role
            var userRole = user.AspNetRoles.FirstOrDefault();

            // Get order and review counts
            int totalOrders = db.Orders.Count(o => o.UserId == userId);
            int totalReviews = db.Reviews.Count(r => r.UserId == userId);

            var model = new ProfileViewModel
            {
                Id = user.Id,
                Email = user.Email,
                FullName = user.FullName,
                PhoneNumber = user.PhoneNumber,
                DateOfBirth = user.DateOfBirth,
                Address = user.Address,
                ProfilePictureUrl = user.ProfilePictureUrl,
                CreatedAt = user.CreatedAt,
                Role = userRole?.Name ?? "Customer",
                TotalOrders = totalOrders,
                TotalReviews = totalReviews
            };

            return View(model);
        }

        // POST: /Account/Profile
        [HttpPost]
        [Authorize]
        [ValidateAntiForgeryToken]
        public ActionResult Profile(ProfileViewModel model)
        {
            if (!ModelState.IsValid)
            {
                return View(model);
            }

            var userId = User.Identity.GetUserId();
            var user = db.AspNetUsers.Find(userId);

            if (user == null)
            {
                return HttpNotFound();
            }

            // Update user profile
            user.FullName = model.FullName;
            user.PhoneNumber = model.PhoneNumber;
            user.DateOfBirth = model.DateOfBirth;
            user.Address = model.Address;
            user.UpdatedAt = DateTime.UtcNow;

            db.SaveChanges();

            TempData["SuccessMessage"] = "Profile updated successfully!";
            return RedirectToAction("Profile");
        }

        // GET: /Account/ChangePassword
        [Authorize]
        public ActionResult ChangePassword()
        {
            return View();
        }

        // POST: /Account/ChangePassword
        [HttpPost]
        [Authorize]
        [ValidateAntiForgeryToken]
        public ActionResult ChangePassword(ChangePasswordViewModel model)
        {
            if (!ModelState.IsValid)
            {
                return View(model);
            }

            var userId = User.Identity.GetUserId();
            var user = db.AspNetUsers.Find(userId);

            if (user == null)
            {
                return HttpNotFound();
            }

            // Verify current password
            var passwordHasher = new Microsoft.AspNet.Identity.PasswordHasher();
            var result = passwordHasher.VerifyHashedPassword(user.PasswordHash, model.CurrentPassword);

            if (result == PasswordVerificationResult.Failed)
            {
                ModelState.AddModelError("CurrentPassword", "Current password is incorrect.");
                return View(model);
            }

            // Update password
            user.PasswordHash = passwordHasher.HashPassword(model.NewPassword);
            user.SecurityStamp = Guid.NewGuid().ToString();
            user.UpdatedAt = DateTime.UtcNow;

            db.SaveChanges();

            TempData["SuccessMessage"] = "Password changed successfully!";
            return RedirectToAction("Profile");
        }

        // GET: /Account/AccessDenied
        [AllowAnonymous]
        public ActionResult AccessDenied()
        {
            return View();
        }

        // GET: /Account/SeedAdmin
        // TEMPORARY: Use this to reset admin password,remove in production
        [AllowAnonymous]
        public ActionResult SeedAdmin()
        {
            var passwordHasher = new Microsoft.AspNet.Identity.PasswordHasher();
            string newPassword = "Admin@123";
            string hashedPassword = passwordHasher.HashPassword(newPassword);

            // Find existing admin user
            var adminUser = db.AspNetUsers.FirstOrDefault(u => u.Email == "admin@bookstore.local");

            if (adminUser != null)
            {
                // Reset password for existing admin
                adminUser.PasswordHash = hashedPassword;
                adminUser.IsActive = true;
                adminUser.LockoutEnd = null;
                adminUser.AccessFailedCount = 0;
                adminUser.UpdatedAt = DateTime.UtcNow;
                db.SaveChanges();

                return Content("Admin password reset successfully!\n\nEmail: admin@bookstore.local\nPassword: Admin@123\n\n⚠️ DELETE THIS ACTION IN PRODUCTION!");
            }

            // Create new admin if doesn't exist
            var adminRole = db.AspNetRoles.FirstOrDefault(r => r.Name == "Admin");
            if (adminRole == null)
            {
                return Content("Error: Admin role not found in database. Please create the Admin role first.");
            }

            var newAdmin = new AspNetUsers
            {
                Id = Guid.NewGuid().ToString(),
                Email = "admin@bookstore.local",
                NormalizedEmail = "ADMIN@BOOKSTORE.LOCAL",
                UserName = "admin@bookstore.local",
                NormalizedUserName = "ADMIN@BOOKSTORE.LOCAL",
                FullName = "Site Admin",
                PhoneNumber = "0000000000",
                DateOfBirth = DateTime.Today.AddYears(-30),
                Address = "Admin Office",
                PasswordHash = hashedPassword,
                SecurityStamp = Guid.NewGuid().ToString(),
                ConcurrencyStamp = Guid.NewGuid().ToString(),
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                IsActive = true,
                IsDeleted = false,
                EmailConfirmed = true,
                PhoneNumberConfirmed = true,
                TwoFactorEnabled = false,
                LockoutEnabled = false,
                AccessFailedCount = 0
            };

            newAdmin.AspNetRoles.Add(adminRole);
            db.AspNetUsers.Add(newAdmin);
            db.SaveChanges();

            return Content("Admin created successfully!\n\nEmail: admin@bookstore.local\nPassword: Admin@123\n\n⚠️ DELETE THIS ACTION IN PRODUCTION!");
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
