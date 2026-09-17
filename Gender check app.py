import streamlit as st
import time

# ----------------------------
# Page setup
# ----------------------------
st.set_page_config(
    page_title="What's Your Type?",
    page_icon="🧬",
    layout="centered",
)

# ----------------------------
# Custom styling
# ----------------------------
st.markdown(
    """
    <style>
    .big-title {
        font-size: 2.6rem;
        font-weight: 800;
        text-align: center;
        background: linear-gradient(90deg, #6a11cb, #2575fc);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        margin-bottom: 0.2rem;
    }
    .subtitle {
        text-align: center;
        color: #888;
        margin-bottom: 2rem;
    }
    .result-card {
        padding: 1.5rem;
        border-radius: 16px;
        background: linear-gradient(135deg, #f5f7fa, #c3cfe2);
        text-align: center;
        font-size: 1.4rem;
        font-weight: 700;
        margin-top: 1.5rem;
        box-shadow: 0 4px 15px rgba(0,0,0,0.1);
    }
    </style>
    """,
    unsafe_allow_html=True,
)

# ----------------------------
# Header
# ----------------------------
st.markdown('<div class="big-title">🧬 What\'s Your Type?</div>', unsafe_allow_html=True)
st.markdown('<div class="subtitle">A wildly scientific 2-question personality classifier</div>', unsafe_allow_html=True)

# ----------------------------
# Persona data: emoji, description, fun fact
# ----------------------------
PERSONAS = {
    ("Male", "Tall"): {
        "emoji": "🧍‍♂️📏",
        "title": "The Tall Male",
        "desc": "You probably get asked to grab things off the top shelf. A lot.",
        "fact": "Fun fact: you've hit your head on a doorframe at least once this year.",
    },
    ("Male", "Short"): {
        "emoji": "🧍‍♂️🐿️",
        "title": "The Short Male",
        "desc": "Compact, efficient, and always first to find a parking spot in tight spaces.",
        "fact": "Fun fact: legroom on flights has never once been a problem for you.",
    },
    ("Female", "Tall"): {
        "emoji": "🧍‍♀️📏",
        "title": "The Tall Female",
        "desc": "Runway-ready posture and a great vantage point at concerts.",
        "fact": "Fun fact: people constantly ask if you play basketball. You don't.",
    },
    ("Female", "Short"): {
        "emoji": "🧍‍♀️🌸",
        "title": "The Short Female",
        "desc": "Small but mighty — you've mastered the art of the step stool.",
        "fact": "Fun fact: you own at least one pair of pants that needed hemming.",
    },
}

# ----------------------------
# Inputs (interactive widgets instead of raw text input)
# ----------------------------
col1, col2 = st.columns(2)

with col1:
    gender = st.radio("👤 Are you Male or Female?", ["Male", "Female"], horizontal=True)

with col2:
    height = st.radio("📏 Are you Tall or Short?", ["Tall", "Short"], horizontal=True)

st.write("")  # spacing

# ----------------------------
# Reveal button with a little animated suspense
# ----------------------------
if st.button("✨ Reveal My Type", use_container_width=True):
    with st.spinner("Analyzing your cosmic proportions..."):
        time.sleep(1)

    persona = PERSONAS[(gender, height)]

    st.markdown(
        f"""
        <div class="result-card">
            <div style="font-size:3rem;">{persona['emoji']}</div>
            <div>{persona['title']}</div>
            <div style="font-size:1rem; font-weight:400; margin-top:0.5rem; color:#444;">
                {persona['desc']}
            </div>
        </div>
        """,
        unsafe_allow_html=True,
    )

    st.info(persona["fact"])
    st.balloons()

    # Keep a running tally in session state, just for fun
    if "history" not in st.session_state:
        st.session_state.history = []
    st.session_state.history.append(persona["title"])

# ----------------------------
# Sidebar: show session history
# ----------------------------
with st.sidebar:
    st.header("📜 Your Session History")
    if "history" in st.session_state and st.session_state.history:
        for i, h in enumerate(reversed(st.session_state.history), 1):
            st.write(f"{i}. {h}")
        if st.button("Clear history"):
            st.session_state.history = []
            st.rerun()
    else:
        st.caption("No results yet — hit the button!")

st.markdown("---")
st.caption("Made with Streamlit • Purely for fun, not actual science 😄")
