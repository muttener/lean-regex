import Regex.NFA.Basic
import Regex.NFA.VM.SparseSet

theorem Array.zero_lt_size_of_not_empty {a : Array α} (hemp : ¬ a.isEmpty) :
  0 < a.size := by
  apply Nat.zero_lt_of_ne_zero
  intro heq
  have : a = #[] := eq_empty_of_size_eq_zero heq
  simp [this] at hemp

def Array.back' (a : Array α) (hemp : ¬ a.isEmpty) : α :=
  have : 0 < a.size := zero_lt_size_of_not_empty hemp
  a[a.size - 1]

theorem Array.lt_size_of_pop_of_not_empty (a : Array α) (hemp : ¬ a.isEmpty) :
  (a.pop).size < a.size := by
  have : 0 < a.size := zero_lt_size_of_not_empty hemp
  have : a.size - 1 < a.size := Nat.sub_lt_of_pos_le (by decide) this
  simp [Array.pop]
  exact this

open NFA.VM
open String (Pos)

/-
  The following implementation is heavily inspired by burntsushi's regex-lite crate.
  https://github.com/rust-lang/regex/tree/master/regex-lite
-/
namespace NFA.VM

-- TODO: embed .none into Pos to remove allocations
inductive StackEntry (n : Nat) : Type where
  | explore (target : Fin n)
  | restore (save : Array (Option Pos))
deriving Repr

mutual

def exploreεClosure (nfa : NFA) (pos : Pos)
  (next : SparseSet nfa.nodes.size)
  (currentSave : Array (Option Pos)) (matched : Option (Array (Option Pos))) (saveSlots : Vec (Array (Option Pos)) nfa.nodes.size)
  (target : Fin nfa.nodes.size) (stack : Array (StackEntry nfa.nodes.size)) :
  (Option (Array (Option Pos)) × SparseSet nfa.nodes.size × Vec (Array (Option Pos)) nfa.nodes.size) :=
  if target ∈ next then
    εClosure nfa pos next currentSave matched saveSlots stack
  else
    let next' := next.insert target
    match hn : nfa[target] with
    | .epsilon target' =>
      have isLt := nfa.inBounds' target hn
      exploreεClosure nfa pos next' currentSave matched saveSlots ⟨target', isLt⟩ stack
    | .split target₁ target₂ =>
      -- NOTE: unpacking the pair here confuses the simplifier
      have isLt := nfa.inBounds' target hn
      exploreεClosure nfa pos next' currentSave matched saveSlots ⟨target₁, isLt.1⟩ (stack.push (.explore ⟨target₂, isLt.2⟩))
    | .save offset target' =>
      have isLt := nfa.inBounds' target hn
      if h : offset < currentSave.size then
        let nextSave := currentSave.set ⟨offset, h⟩ pos
        let stack' := stack.push (.restore currentSave)
        exploreεClosure nfa pos next' nextSave matched saveSlots ⟨target', isLt⟩ stack'
      else
        exploreεClosure nfa pos next' currentSave matched saveSlots ⟨target', isLt⟩ stack
    | .done =>
      let matched' := matched <|> currentSave
      let saveSlots' := saveSlots.set target target.isLt currentSave
      εClosure nfa pos next' currentSave matched' saveSlots' stack
    | .char _ _ =>
      let saveSlots' := saveSlots.set target target.isLt currentSave
      εClosure nfa pos next' currentSave matched saveSlots' stack
    | .sparse _ _ =>
      let saveSlots' := saveSlots.set target target.isLt currentSave
      εClosure nfa pos next' currentSave matched saveSlots' stack
    | .fail => εClosure nfa pos next' currentSave matched saveSlots stack
termination_by (next.measure, stack.size, 1)

def εClosure (nfa : NFA) (pos : Pos)
  (next : SparseSet nfa.nodes.size)
  (currentSave : Array (Option Pos)) (matched : Option (Array (Option Pos))) (saveSlots : Vec (Array (Option Pos)) nfa.nodes.size)
  (stack : Array (StackEntry nfa.nodes.size)) :
  (Option (Array (Option Pos)) × SparseSet nfa.nodes.size × Vec (Array (Option Pos)) nfa.nodes.size) :=
  if hemp : stack.isEmpty then
    (matched, next, saveSlots)
  else
    let entry := stack.back' hemp
    let stack' := stack.pop
    have : stack'.size < stack.size := Array.lt_size_of_pop_of_not_empty _ hemp
    match entry with
    | .explore target => exploreεClosure nfa pos next currentSave matched saveSlots target stack'
    | .restore save => εClosure nfa pos next save matched saveSlots stack'
termination_by (next.measure, stack.size, 0)

end

def stepChar (nfa : NFA) (c : Char) (pos : Pos)
  (next : SparseSet nfa.nodes.size)
  (saveSlots : Vec (Array (Option Pos)) nfa.nodes.size)
  (target : Fin nfa.nodes.size) :
  (Option (Array (Option Pos)) × SparseSet nfa.nodes.size × Vec (Array (Option Pos)) nfa.nodes.size) :=
  match hn : nfa[target] with
  | .char c' target' =>
    if c = c' then
      have isLt := nfa.inBounds' target hn
      let currentSave := saveSlots.get target target.isLt
      exploreεClosure nfa pos next currentSave .none saveSlots ⟨target', isLt⟩ .empty
    else
      (.none, next, saveSlots)
  | .sparse cs target' =>
    if c ∈ cs then
      have isLt := nfa.inBounds' target hn
      let currentSave := saveSlots.get target target.isLt
      exploreεClosure nfa pos next currentSave .none saveSlots ⟨target', isLt⟩ .empty
    else
      (.none, next, saveSlots)
  -- We don't need this as εClosure figures it out if there is a match
  -- | .done =>
  --   -- Return saved positions at the match
  --   (.some saveSlots[target], next, saveSlots)
  | _ => (.none, next, saveSlots)

def eachStepChar (nfa : NFA) (c : Char) (pos : Pos)
  (current : SparseSet nfa.nodes.size) (next : SparseSet nfa.nodes.size)
  (saveSlots : Vec (Array (Option Pos)) nfa.nodes.size) :
  (Option (Array (Option Pos)) × SparseSet nfa.nodes.size × Vec (Array (Option Pos)) nfa.nodes.size) :=
  go 0 (Nat.zero_le _) next saveSlots
where
  go (i : Nat) (hle : i ≤ current.count) (next : SparseSet nfa.nodes.size) (saveSlots : Vec (Array (Option Pos)) nfa.nodes.size) :
    (Option (Array (Option Pos)) × SparseSet nfa.nodes.size × Vec (Array (Option Pos)) nfa.nodes.size) :=
    if h : i = current.count then
      (.none, next, saveSlots)
    else
      have hlt : i < current.count := Nat.lt_of_le_of_ne hle h
      let result := stepChar nfa c pos next saveSlots current[i]
      match result.1 with
      | .none => go (i + 1) hlt result.2.1 result.2.2
      | .some _ => result
  termination_by current.count - i

end NFA.VM

def NFA.captureNext (nfa : NFA) (it : String.Iterator) (saveSize : Nat) : Option (Array (Option Pos)) :=
  let saveSlots := Vec.ofFn (fun _ => initSave)
  let (matched, init, saveSlots) :=
    NFA.VM.exploreεClosure nfa it.pos .empty initSave .none saveSlots nfa.start #[]
  go it init .empty saveSlots matched
where
  initSave : Array (Option Pos) := Array.ofFn (fun _ : Fin saveSize => none)
  go (it : String.Iterator)
    (current : SparseSet nfa.nodes.size) (next : SparseSet nfa.nodes.size)
    (saveSlots : Vec (Array (Option Pos)) nfa.nodes.size)
    (lastMatch : Option (Array (Option Pos)))
    : Option (Array (Option Pos)) := do
    if it.atEnd then
      lastMatch
    else
      if current.isEmpty && lastMatch.isSome then
        lastMatch
      else
        -- Start a new search from the current position only when there is no match
        let currentAndSaveSlots := if lastMatch.isNone then
          -- I think ignoring the match here is fine because the match must have happened at the initial exploration
          -- and `lastMatch` must have already captured that.
          let explored := NFA.VM.exploreεClosure nfa it.pos current initSave .none saveSlots nfa.start #[]
          explored.2
        else
          (current, saveSlots)
        let stepped := NFA.VM.eachStepChar nfa it.curr it.next.pos currentAndSaveSlots.1 next currentAndSaveSlots.2
        go it.next stepped.2.1 current.clear stepped.2.2 (stepped.1 <|> lastMatch)

def NFA.searchNext (nfa : NFA) (it : String.Iterator) : Option (Pos × Pos) := do
  let slots ← nfa.captureNext it 2
  let first ← (←slots.get? 0)
  let second ← (←slots.get? 1)
  pure (first, second)

structure NFA.Matches where
  nfa : NFA
  heystack : String
  currentPos : Pos
deriving Repr

@[export lean_regex_nfa_matches]
def NFA.matches (nfa : NFA) (s : String) : NFA.Matches :=
  { nfa := nfa, heystack := s, currentPos := 0 }

@[export lean_regex_nfa_matches_next]
def NFA.Matches.next? (self : NFA.Matches) : Option ((Pos × Pos) × NFA.Matches) := do
  let pos ← self.nfa.searchNext ⟨self.heystack, self.currentPos⟩
  if self.currentPos < pos.2 then
    let next := { self with currentPos := pos.2 }
    pure (pos, next)
  else
    let next := { self with currentPos := self.heystack.next self.currentPos }
    pure (pos, next)

instance : Stream NFA.Matches (Pos × Pos) := ⟨NFA.Matches.next?⟩
