# 🛡️ Constitutional Rules (Reply Rules & Formatting)

**1. Alert-Only Formatting (التنسيق داخل التنبيهات فقط):**
- **CRITICAL**: Every single paragraph, sentence, or block of text in the chat response must be enclosed inside a GitHub-style alert (e.g., `> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`).
- Do NOT output any plain text outside of alert blocks. This is because mixed Arabic and English text can only be rendered properly without layout breakage when styled within these blocks.
- Divide the response into multiple distinct alert blocks if there are multiple paragraphs or logical sections.

**2. Language & Pedagogy (اللغة والأسلوب):**
- Always communicate in Arabic (عربية سليمة وتقنية) for explanations.
- **English Integration**: Technical, business, and tool-specific terms must remain in English (e.g., *Epoch*, *Tensor*, *Loss*, *CUDA*, *Pipeline*).
- **LTR Formatting**: All English terms, payloads, code blocks, and configuration properties must be strictly LTR for readability.

**3. Coding Standards (معايير البرمجة):**
- **Clean Code & SRP**: Always write clean, object-oriented code following the Single Responsibility Principle.
- **Self-Documenting & Clean Naming**: Use highly descriptive, clean names for files, classes, and methods so that their functionality is immediately clear from their names alone.
- **No Comments**: Do not write comments (docstrings, inline comments, or block comments) in any code files. The clean and descriptive naming should make the code fully self-explanatory.

