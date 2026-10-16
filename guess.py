import random
import streamlit as st

secret_words = {
    "Ashwin": "Nerd",
    "Ragul": "Gossiper",
    "Ajay": "Capturer",
    "Aman": "Anna",
    "Gurumoorthy": "Sportsman",
    "Harsha": "Sleepyhead",
    "Ranganathan": "Mathematician",
    "Saffer": "Gymboy",
    "Shakel": "Footballer",
    "Aadhavan": "Topper",
    "Tharun": "Rebel",
    "Dinesh Baalaji": "Optimist",
    "Anirudh": "Athlete",
    "Koushik": "Leader",
}

GUESS_LIMIT = 3

st.set_page_config(page_title="Guess Your Personality", page_icon="🎯")
st.title("🎯 Guess Your Personality")


def reset_game():
    st.session_state.name = None
    st.session_state.guess_count = 0
    st.session_state.status = "playing"  # playing | won | lost
    st.session_state.history = []
    st.session_state.hints_used = 0
    st.session_state.options = []


def start_game(name):
    # All personalities, alphabetical so the order gives nothing away
    options = sorted(secret_words.values())
    st.session_state.name = name
    st.session_state.guess_count = 0
    st.session_state.status = "playing"
    st.session_state.history = []
    st.session_state.hints_used = 0
    st.session_state.options = options


if "status" not in st.session_state:
    reset_game()
    st.session_state.wins = 0
    st.session_state.losses = 0


def record_guess(guess, secret_word):
    st.session_state.guess_count += 1
    correct = guess.title().strip() == secret_word
    st.session_state.history.append((guess.strip() or "(blank)", correct))
    left = GUESS_LIMIT - st.session_state.guess_count
    if correct:
        st.session_state.status = "won"
        st.session_state.wins += 1
    elif left <= 0:
        st.session_state.status = "lost"
        st.session_state.losses += 1
    else:
        st.toast(f"Wrong! {left} guess(es) left", icon="❌")


# ---------- Sidebar ----------
with st.sidebar:
    st.header("📊 Scoreboard")
    c1, c2 = st.columns(2)
    c1.metric("Wins", st.session_state.get("wins", 0))
    c2.metric("Losses", st.session_state.get("losses", 0))

    if st.session_state.history:
        st.subheader("Your guesses")
        for i, (g, ok) in enumerate(st.session_state.history, 1):
            st.write(f"{i}. {g} {'✅' if ok else '❌'}")

    st.divider()
    easy_mode = st.toggle("Choose from list", value=True)
    st.caption("On: pick from all personalities. Off: type your guess.")

# ---------- Step 1: enter name ----------
if st.session_state.name is None:
    st.write("Enter your name to find out if you can guess your own personality tag.")
    with st.expander("👀 See all personalities"):
        for w in sorted(secret_words.values()):
            st.write(f"• {w}")
    with st.form("name_form"):
        entered = st.text_input("Enter your name:")
        submitted = st.form_submit_button("Start 🚀")

    if submitted:
        name = entered.title().strip()
        if name in secret_words:
            start_game(name)
            st.rerun()
        else:
            st.error("Sorry, You are not part of this game")

# ---------- Step 2: guessing ----------
else:
    name = st.session_state.name
    secret_word = secret_words[name]
    used = st.session_state.guess_count
    left = GUESS_LIMIT - used

    st.subheader(f"Hi {name} 👋")

    # Lives + progress
    st.write("Lives: " + "❤️" * left + "🖤" * used)
    st.progress(used / GUESS_LIMIT, text=f"Attempt {min(used + 1, GUESS_LIMIT)} of {GUESS_LIMIT}")

    if st.session_state.status == "playing":
        # Hints (outside the form so the button works instantly)
        hint_col, _ = st.columns([1, 2])
        if hint_col.button("💡 Get a hint", disabled=st.session_state.hints_used >= 2):
            st.session_state.hints_used += 1

        if st.session_state.hints_used >= 1:
            st.info(f"Hint 1: It has {len(secret_word)} letters.")
        if st.session_state.hints_used >= 2:
            st.info(f"Hint 2: It starts with '{secret_word[0]}'.")

        # Guess form
        with st.form("guess_form", clear_on_submit=True):
            if easy_mode:
                guess = st.selectbox(
                    "Guess your personality:",
                    st.session_state.options,
                    index=None,
                    placeholder="Choose a personality...",
                )
            else:
                guess = st.text_input("Guess your personality:")
            submitted = st.form_submit_button("Submit guess ✅")

        if submitted:
            if easy_mode and guess is None:
                st.warning("Pick an option first.")
            else:
                record_guess(guess or "", secret_word)
                st.rerun()

    if st.session_state.status == "won":
        st.success(f"Correct 🎉 You are the **{secret_word}**!")
        st.balloons()
    elif st.session_state.status == "lost":
        st.error("Out of guesses, You lose")
        st.info(f"The answer was **{secret_word}**.")
        st.snow()

    if st.session_state.status != "playing":
        if st.button("🔄 Play again"):
            reset_game()
            st.rerun()
