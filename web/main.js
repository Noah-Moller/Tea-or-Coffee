const DEFAULT_SESSION_NAME = "web-session";

let cart = [];
let popularItems = new Map();

async function ensureSession() {
  try {
    const res = await fetch("/session/current");
    if (res.ok) {
      const data = await res.json();
      if (data.sessionName && data.sessionName.trim() !== "") {
        return;
      }
    }
  } catch {
    // Ignore and fall through to creating a default session.
  }

  await fetch("/session/create", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ sessionName: DEFAULT_SESSION_NAME }),
  });
}

async function loadMenu() {
  try {
    const response = await fetch("/menu");
    if (!response.ok) {
      throw new Error(`Failed to load menu (${response.status})`);
    }
    const data = await response.json();
    return data.menu || [];
  } catch (error) {
    console.error(error);
    showToast("Could not load menu. Please try again.", true);
    return [];
  }
}

async function loadPopular() {
  try {
    const response = await fetch("/popular");
    if (!response.ok) {
      return; // Popular items are optional
    }
    const data = await response.json();
    popularItems.clear();
    for (const item of data.items || []) {
      popularItems.set(item.drink, item.count);
    }
  } catch (error) {
    console.error(error);
  }
}

function getDrinkEmoji(drink) {
  const emojiMap = {
    Espresso: "☕",
    Americano: "☕",
    Latte: "☕",
    Cappuccino: "☕",
    "Flat White": "☕",
    Mocha: "☕",
    Macchiato: "☕",
    "Iced Latte": "🧊",
    "Iced Americano": "🧊",
    "Hot Chocolate": "🍫",
  };
  return emojiMap[drink] || "☕";
}

function renderDrinkCard(drink) {
  const card = document.createElement("div");
  card.className = "drink-card";
  card.setAttribute("data-drink", drink);

  const emoji = document.createElement("div");
  emoji.className = "drink-card__emoji";
  emoji.textContent = getDrinkEmoji(drink);

  const name = document.createElement("div");
  name.className = "drink-card__name";
  name.textContent = drink;

  card.appendChild(emoji);
  card.appendChild(name);

  const count = popularItems.get(drink);
  if (count !== undefined && count > 0) {
    const popular = document.createElement("div");
    popular.className = "drink-card__popular";
    popular.textContent = "⭐ Popular";
    const countEl = document.createElement("div");
    countEl.className = "drink-card__count";
    countEl.textContent = `${count} orders`;
    card.appendChild(popular);
    card.appendChild(countEl);
  }

  card.addEventListener("click", () => {
    openItemModal(drink);
  });

  return card;
}

function renderMenu(menu) {
  const menuGrid = document.getElementById("menu-grid");
  if (!menuGrid) return;

  menuGrid.innerHTML = "";
  for (const drink of menu) {
    menuGrid.appendChild(renderDrinkCard(drink));
  }
}

function renderPopular() {
  const popularSection = document.getElementById("popular-section");
  const popularGrid = document.getElementById("popular-grid");
  if (!popularSection || !popularGrid) return;

  const topItems = Array.from(popularItems.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 6)
    .map(([drink]) => drink);

  if (topItems.length === 0) {
    popularSection.style.display = "none";
    return;
  }

  popularSection.style.display = "block";
  popularGrid.innerHTML = "";
  for (const drink of topItems) {
    popularGrid.appendChild(renderDrinkCard(drink));
  }
}

function updateCartCount() {
  const cartCount = document.getElementById("cart-count");
  if (cartCount) {
    cartCount.textContent = cart.length.toString();
  }
}

function renderCart() {
  const cartItems = document.getElementById("cart-items");
  const checkoutButton = document.getElementById("checkout-button");
  const cartTotalCount = document.getElementById("cart-total-count");

  if (!cartItems || !checkoutButton || !cartTotalCount) return;

  cartItems.innerHTML = "";

  if (cart.length === 0) {
    const empty = document.createElement("div");
    empty.style.textAlign = "center";
    empty.style.color = "#6b7280";
    empty.style.padding = "40px 20px";
    empty.textContent = "Your cart is empty";
    cartItems.appendChild(empty);
    checkoutButton.disabled = true;
    cartTotalCount.textContent = "0";
    return;
  }

  checkoutButton.disabled = false;
  cartTotalCount.textContent = cart.length.toString();

  cart.forEach((item, index) => {
    const cartItem = document.createElement("div");
    cartItem.className = "cart-item";

    const header = document.createElement("div");
    header.className = "cart-item__header";

    const name = document.createElement("div");
    name.className = "cart-item__name";
    name.textContent = item.drink;

    const remove = document.createElement("button");
    remove.className = "cart-item__remove";
    remove.textContent = "×";
    remove.setAttribute("aria-label", "Remove item");
    remove.addEventListener("click", () => {
      cart.splice(index, 1);
      renderCart();
      updateCartCount();
    });

    header.appendChild(name);
    header.appendChild(remove);

    const instructions = document.createElement("div");
    instructions.className = "cart-item__instructions";
    instructions.textContent = item.instructions || "No special instructions";

    const edit = document.createElement("button");
    edit.className = "cart-item__edit";
    edit.textContent = "Edit instructions";
    edit.addEventListener("click", () => {
      openItemModal(item.drink, item.instructions, index);
    });

    cartItem.appendChild(header);
    cartItem.appendChild(instructions);
    cartItem.appendChild(edit);

    cartItems.appendChild(cartItem);
  });
}

function openItemModal(drink, existingInstructions, cartIndex) {
  const modal = document.getElementById("item-modal");
  const title = document.getElementById("item-modal-title");
  const drinkInput = document.getElementById("item-drink");
  const instructionsInput = document.getElementById("item-instructions");
  const form = document.getElementById("item-form");

  if (!modal || !title || !drinkInput || !instructionsInput || !form) return;

  title.textContent = cartIndex !== undefined ? "Edit item" : "Add to cart";
  drinkInput.value = drink;
  instructionsInput.value = existingInstructions || "";

  modal.classList.add("open");

  const handleSubmit = (e) => {
    e.preventDefault();
    const instructions = instructionsInput.value.trim();

    if (cartIndex !== undefined) {
      cart[cartIndex].instructions = instructions;
    } else {
      cart.push({ drink, instructions });
    }

    renderCart();
    updateCartCount();
    closeItemModal();
    form.removeEventListener("submit", handleSubmit);
  };

  form.addEventListener("submit", handleSubmit);
}

function closeItemModal() {
  const modal = document.getElementById("item-modal");
  const form = document.getElementById("item-form");
  if (modal) {
    modal.classList.remove("open");
  }
  if (form) {
    form.reset();
  }
}

function openCheckoutModal() {
  const modal = document.getElementById("checkout-modal");
  const form = document.getElementById("checkout-form");
  const nameInput = document.getElementById("customer-name");

  if (!modal || !form || !nameInput) return;

  nameInput.value = "";
  modal.classList.add("open");
  nameInput.focus();

  const handleSubmit = async (e) => {
    e.preventDefault();
    const customerName = nameInput.value.trim();

    if (!customerName) {
      showToast("Please enter your name", true);
      return;
    }

    if (cart.length === 0) {
      showToast("Your cart is empty", true);
      return;
    }

    // Disable form during submission
    const submitButton = form.querySelector('button[type="submit"]');
    if (submitButton) {
      submitButton.disabled = true;
    }

    try {
      let successCount = 0;
      let errorCount = 0;

      for (const item of cart) {
        try {
          const response = await fetch("/order", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              drink: item.drink,
              customerName,
              instructions: item.instructions,
            }),
          });

          if (!response.ok) {
            errorCount++;
            continue;
          }

          successCount++;
        } catch (error) {
          console.error("Error placing order:", error);
          errorCount++;
        }
      }

      if (successCount > 0) {
        showToast(
          `Successfully placed ${successCount} order${successCount > 1 ? "s" : ""}!`,
          false
        );
        cart = [];
        renderCart();
        updateCartCount();
        closeCheckoutModal();
        await loadPopular(); // Refresh popular items
        renderPopular();
      } else {
        showToast("Failed to place orders. Please try again.", true);
      }

      if (errorCount > 0 && successCount > 0) {
        showToast(`${errorCount} order${errorCount > 1 ? "s" : ""} failed`, true);
      }
    } catch (error) {
      console.error(error);
      showToast("Could not place orders. Please try again.", true);
    } finally {
      const submitButton = form.querySelector('button[type="submit"]');
      if (submitButton) {
        submitButton.disabled = false;
      }
    }

    form.removeEventListener("submit", handleSubmit);
  };

  form.addEventListener("submit", handleSubmit);
}

function closeCheckoutModal() {
  const modal = document.getElementById("checkout-modal");
  if (modal) {
    modal.classList.remove("open");
  }
}

function showToast(message, isError) {
  const toast = document.getElementById("status-toast");
  if (!toast) return;

  toast.textContent = message;
  toast.className = `toast ${isError ? "error" : "success"}`;
  toast.classList.add("show");

  setTimeout(() => {
    toast.classList.remove("show");
  }, 3000);
}

window.addEventListener("DOMContentLoaded", async () => {
  await ensureSession();

  // Load data
  const menu = await loadMenu();
  await loadPopular();

  // Render UI
  renderMenu(menu);
  renderPopular();
  renderCart();
  updateCartCount();

  // Cart sidebar
  const cartButton = document.getElementById("cart-button");
  const closeCart = document.getElementById("close-cart");
  const cartSidebar = document.getElementById("cart-sidebar");
  const checkoutButton = document.getElementById("checkout-button");

  if (cartButton && cartSidebar) {
    cartButton.addEventListener("click", () => {
      cartSidebar.classList.add("open");
    });
  }

  if (closeCart && cartSidebar) {
    closeCart.addEventListener("click", () => {
      cartSidebar.classList.remove("open");
    });
  }

  if (checkoutButton) {
    checkoutButton.addEventListener("click", () => {
      if (cart.length > 0) {
        openCheckoutModal();
      }
    });
  }

  // Item modal
  const cancelItem = document.getElementById("cancel-item");
  if (cancelItem) {
    cancelItem.addEventListener("click", closeItemModal);
  }

  // Checkout modal
  const cancelCheckout = document.getElementById("cancel-checkout");
  if (cancelCheckout) {
    cancelCheckout.addEventListener("click", closeCheckoutModal);
  }

  // Close modals on backdrop click
  const itemModal = document.getElementById("item-modal");
  const checkoutModal = document.getElementById("checkout-modal");

  if (itemModal) {
    itemModal.addEventListener("click", (e) => {
      if (e.target === itemModal) {
        closeItemModal();
      }
    });
  }

  if (checkoutModal) {
    checkoutModal.addEventListener("click", (e) => {
      if (e.target === checkoutModal) {
        closeCheckoutModal();
      }
    });
  }
});
