import Regex.Regex.Basic

open String (Pos)

namespace Regex

structure Matches where
  regex : Regex
  haystack : String
  currentPos : Pos
deriving Repr

def Matches.next? (self : Matches) : Option ((Pos × Pos) × Matches) := do
  if self.currentPos < self.haystack.endPos then
    let pos ← VM.searchNext self.regex.nfa ⟨self.haystack, self.currentPos⟩
    if self.currentPos < pos.2 then
      let next := { self with currentPos := pos.2 }
      pure (pos, next)
    else
      let next := { self with currentPos := self.haystack.next self.currentPos }
      pure (pos, next)
  else
    throw ()

def Matches.remaining (self : Matches) : Pos :=
  self.haystack.endPos - self.currentPos

theorem Matches.lt_next?_some {m : Matches} (h : m.next? = some (pos, m')) :
  m.currentPos < m'.currentPos := by
  unfold next? at h
  split at h <;> simp [Option.bind_eq_some] at h
  have ⟨_, _, h⟩ := h
  split at h <;> simp at h
  next h' => simp [←h, h']
  next =>
    simp [←h, String.next]
    have : (m.haystack.get m.currentPos).utf8Size > 0 := Char.utf8Size_pos _
    omega

theorem Matches.next?_decreasing {m : Matches} (h : m.next? = some (pos, m')) :
  m'.remaining < m.remaining := by
  unfold remaining
  have : m'.haystack = m.haystack := by
    unfold next? at h
    split at h <;> simp [Option.bind_eq_some] at h
    have ⟨_, _, h⟩ := h
    split at h <;> simp at h <;> simp [←h]
  rw [this]
  have h₁ : m.currentPos < m'.currentPos := lt_next?_some h
  have h₂ : m.currentPos < m.haystack.endPos := by
    by_contra nlt
    simp [next?, nlt] at h
  exact Nat.sub_lt_sub_left h₂ h₁

theorem _root_.String.Pos.sizeOf_eq {p : Pos} : sizeOf p = 1 + p.byteIdx := rfl
theorem _root_.String.Pos.sizeOf_lt_iff {p p' : Pos} :
  sizeOf p < sizeOf p' ↔ p < p' := by
  simp [String.Pos.sizeOf_eq]
  omega

macro_rules | `(tactic| decreasing_trivial) => `(tactic|
  rw [String.Pos.sizeOf_lt_iff];
  exact Matches.next?_decreasing (by assumption))

instance : Stream Matches (Pos × Pos) := ⟨Matches.next?⟩

end Regex

def Regex.matches (regex : Regex) (s : String) : Matches :=
  { regex := regex, haystack := s, currentPos := 0 }
