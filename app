"""IntelliX Portfolio Challenge - virtual stock game with near real-time NSE prices.
Run locally:  streamlit run app.py
"""
import hashlib
import sqlite3
from datetime import datetime

import pandas as pd
import pytz
import streamlit as st
import yfinance as yf

# ---------- SETTINGS (edit these) ----------
START_CASH = 1_000_000          # virtual rupees every player starts with
REFRESH_SECONDS = 30            # how often prices and leaderboard update
ENFORCE_MARKET_HOURS = False    # True = trading allowed only 9:15-15:30 IST, Mon-Fri
CONTEST_NAME = "IntelliX Portfolio Challenge"
STOCKS = {
    "Reliance": "RELIANCE.NS", "TCS": "TCS.NS", "HDFC Bank": "HDFCBANK.NS",
    "Infosys": "INFY.NS", "ICICI Bank": "ICICIBANK.NS", "SBI": "SBIN.NS",
    "ITC": "ITC.NS", "L&T": "LT.NS", "Bharti Airtel": "BHARTIARTL.NS",
    "Axis Bank": "AXISBANK.NS", "Tata Motors": "TATAMOTORS.NS",
    "Sun Pharma": "SUNPHARMA.NS", "Maruti": "MARUTI.NS",
    "Titan": "TITAN.NS", "Asian Paints": "ASIANPAINT.NS",
}
DB_FILE = "portfolio.db"
IST = pytz.timezone("Asia/Kolkata")

st.set_page_config(page_title=CONTEST_NAME, page_icon="📈", layout="wide")


# ---------- DATABASE ----------
@st.cache_resource
def get_db():
    con = sqlite3.connect(DB_FILE, check_same_thread=False)
    con.executescript(
        """
        CREATE TABLE IF NOT EXISTS players(name TEXT PRIMARY KEY, pin_hash TEXT, cash REAL);
        CREATE TABLE IF NOT EXISTS holdings(name TEXT, symbol TEXT, qty INTEGER, avg REAL,
                                            PRIMARY KEY(name, symbol));
        CREATE TABLE IF NOT EXISTS trades(ts TEXT, name TEXT, symbol TEXT, side TEXT,
                                          qty INTEGER, price REAL);
        """
    )
    return con


def hash_pin(name, pin):
    return hashlib.sha256(f"intellix:{name.lower()}:{pin}".encode()).hexdigest()


def login_or_register(name, pin):
    con = get_db()
    row = con.execute("SELECT pin_hash FROM players WHERE name=?", (name,)).fetchone()
    if row is None:
        with con:
            con.execute("INSERT INTO players VALUES(?,?,?)", (name, hash_pin(name, pin), START_CASH))
        return True, "Account created. Good luck!"
    if row[0] == hash_pin(name, pin):
        return True, "Welcome back!"
    return False, "That name is taken and the PIN does not match."


# ---------- LIVE PRICES ----------
@st.cache_data(ttl=REFRESH_SECONDS)
def get_prices():
    """Latest available price per stock (live during market hours, last close otherwise)."""
    symbols = list(STOCKS.values())
    data = yf.download(symbols, period="5d", interval="1m", progress=False,
                       auto_adjust=True, group_by="column", threads=True)
    close = data["Close"].ffill()
    last = close.iloc[-1]
    stamp = close.index[-1]
    prices = {s: float(last[s]) for s in symbols if pd.notna(last[s])}
    return prices, stamp


def market_open():
    now = datetime.now(IST)
    if now.weekday() >= 5:
        return False
    return (now.hour, now.minute) >= (9, 15) and (now.hour, now.minute) <= (15, 30)


# ---------- PORTFOLIO LOGIC ----------
def get_state(name):
    con = get_db()
    cash = con.execute("SELECT cash FROM players WHERE name=?", (name,)).fetchone()[0]
    hold = pd.read_sql_query("SELECT symbol, qty, avg FROM holdings WHERE name=? AND qty>0",
                             con, params=(name,))
    return cash, hold


def trade(name, symbol, side, qty, price):
    con = get_db()
    cash, hold = get_state(name)
    owned = int(hold.loc[hold.symbol == symbol, "qty"].sum()) if not hold.empty else 0
    cost = qty * price
    if side == "BUY":
        if cost > cash:
            return False, f"Not enough cash. You need ₹{cost:,.0f}, you have ₹{cash:,.0f}."
        with con:
            con.execute("UPDATE players SET cash=cash-? WHERE name=?", (cost, name))
            if owned:
                avg = float(hold.loc[hold.symbol == symbol, "avg"].iloc[0])
                new_avg = (avg * owned + cost) / (owned + qty)
                con.execute("UPDATE holdings SET qty=qty+?, avg=? WHERE name=? AND symbol=?",
                            (qty, new_avg, name, symbol))
            else:
                con.execute("INSERT OR REPLACE INTO holdings VALUES(?,?,?,?)", (name, symbol, qty, price))
    else:
        if qty > owned:
            return False, f"You only own {owned} shares."
        with con:
            con.execute("UPDATE players SET cash=cash+? WHERE name=?", (cost, name))
            con.execute("UPDATE holdings SET qty=qty-? WHERE name=? AND symbol=?", (qty, name, symbol))
    with con:
        con.execute("INSERT INTO trades VALUES(?,?,?,?,?,?)",
                    (datetime.now(IST).isoformat(timespec="seconds"), name, symbol, side, qty, price))
    return True, f"{side} {qty} × {symbol.replace('.NS', '')} at ₹{price:,.2f}"


def portfolio_value(cash, hold, prices):
    if hold.empty:
        return cash
    return cash + sum(r.qty * prices.get(r.symbol, r.avg) for r in hold.itertuples())


# ---------- UI PIECES ----------
@st.fragment(run_every=REFRESH_SECONDS)
def leaderboard():
    prices, stamp = get_prices()
    con = get_db()
    players = [r[0] for r in con.execute("SELECT name FROM players")]
    rows = []
    for p in players:
        cash, hold = get_state(p)
        val = portfolio_value(cash, hold, prices)
        rows.append({"Player": p, "Portfolio value (₹)": round(val),
                     "Return %": round((val / START_CASH - 1) * 100, 2)})
    st.subheader("🏆 Leaderboard")
    st.caption(f"Last price update: {pd.Timestamp(stamp).tz_convert(IST):%d %b %H:%M} IST · "
               f"refreshes every {REFRESH_SECONDS}s")
    if rows:
        df = pd.DataFrame(rows).sort_values("Return %", ascending=False).reset_index(drop=True)
        df.index += 1
        st.dataframe(df.head(20), use_container_width=True)
    else:
        st.info("No players yet. Be the first!")


@st.fragment(run_every=REFRESH_SECONDS)
def my_portfolio(name):
    prices, _ = get_prices()
    cash, hold = get_state(name)
    total = portfolio_value(cash, hold, prices)
    c1, c2, c3 = st.columns(3)
    c1.metric("Total value", f"₹{total:,.0f}", f"{(total / START_CASH - 1) * 100:.2f}%")
    c2.metric("Cash", f"₹{cash:,.0f}")
    c3.metric("Invested", f"₹{total - cash:,.0f}")
    if not hold.empty:
        hold = hold.copy()
        hold["Stock"] = hold.symbol.str.replace(".NS", "", regex=False)
        hold["Live price"] = hold.symbol.map(prices)
        hold["P&L ₹"] = ((hold["Live price"] - hold.avg) * hold.qty).round(0)
        hold["P&L %"] = ((hold["Live price"] / hold.avg - 1) * 100).round(2)
        st.dataframe(hold[["Stock", "qty", "avg", "Live price", "P&L ₹", "P&L %"]]
                     .rename(columns={"qty": "Qty", "avg": "Avg buy"}).round(2),
                     use_container_width=True, hide_index=True)
    else:
        st.info("You have no holdings yet. Make your first trade below.")


# ---------- MAIN APP ----------
st.title(f"📈 {CONTEST_NAME}")
st.caption(f"Start with ₹{START_CASH:,.0f} of virtual money, trade top NSE stocks at live prices, "
           "and climb the leaderboard. No real money involved.")

with st.sidebar:
    st.header("Join / Login")
    name = st.text_input("Your name", max_chars=20).strip()
    pin = st.text_input("4-digit PIN", type="password", max_chars=4)
    if st.button("Enter", type="primary"):
        if not name or len(pin) != 4 or not pin.isdigit():
            st.error("Enter a name and a 4-digit PIN.")
        else:
            ok, msg = login_or_register(name, pin)
            if ok:
                st.session_state["player"] = name
                st.success(msg)
            else:
                st.error(msg)
    st.markdown("---")
    st.write("🟢 Market open" if market_open() else "🔴 Market closed (prices show last close)")
    st.caption("Prices come from Yahoo Finance and may be delayed. For a game, not for investing.")

try:
    prices, _ = get_prices()
except Exception as e:  # network or data problem
    st.error("Could not load prices right now. Please refresh in a minute.")
    st.stop()

tab_trade, tab_board = st.tabs(["💼 My portfolio & trading", "🏆 Leaderboard"])

with tab_board:
    leaderboard()

with tab_trade:
    player = st.session_state.get("player")
    if not player:
        st.info("Join using the sidebar to start trading.")
    else:
        st.subheader(f"Hello, {player}")
        my_portfolio(player)
        st.subheader("Place a trade")
        if ENFORCE_MARKET_HOURS and not market_open():
            st.warning("Trading is open 9:15 AM to 3:30 PM IST, Monday to Friday.")
        else:
            c1, c2, c3 = st.columns([2, 1, 1])
            pick = c1.selectbox("Stock", list(STOCKS.keys()))
            qty = c2.number_input("Quantity", min_value=1, value=10, step=1)
            sym = STOCKS[pick]
            px = prices.get(sym)
            if px:
                c3.metric("Live price", f"₹{px:,.2f}")
                b, s = st.columns(2)
                if b.button("Buy", use_container_width=True):
                    ok, msg = trade(player, sym, "BUY", int(qty), px)
                    (st.success if ok else st.error)(msg)
                    if ok:
                        st.rerun()
                if s.button("Sell", use_container_width=True):
                    ok, msg = trade(player, sym, "SELL", int(qty), px)
                    (st.success if ok else st.error)(msg)
                    if ok:
                        st.rerun()
            else:
                st.warning("Price unavailable for this stock right now.")
