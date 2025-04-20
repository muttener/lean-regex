import Regex.Data.String
import Regex.NFA
import Regex.Strategy
import Regex.Backtracker.BitMatrix

open String (Iterator Pos)

set_option autoImplicit false

namespace Regex.Backtracker

structure BoundedIterator (startIdx : Nat) where
  it : Iterator
  ge : startIdx ≤ it.pos.byteIdx
  le : it.pos ≤ it.toString.endPos

namespace BoundedIterator

def maxIdx {startIdx : Nat} (bit : BoundedIterator startIdx) : Nat := bit.it.toString.endPos.byteIdx

def pos {startIdx : Nat} (bit : BoundedIterator startIdx) : String.Pos := bit.it.pos

def index {startIdx : Nat} (bit : BoundedIterator startIdx) : Fin (bit.maxIdx + 1 - startIdx) :=
  have lt : bit.it.pos.byteIdx - startIdx < bit.maxIdx + 1 - startIdx := by
    exact Nat.sub_lt_sub_right bit.ge (Nat.lt_of_le_of_lt bit.le (Nat.lt_succ_self _))
  ⟨bit.it.pos.byteIdx - startIdx, lt⟩

def index' {startIdx maxIdx : Nat} (bit : BoundedIterator startIdx) (h : bit.maxIdx = maxIdx) : Fin (maxIdx + 1 - startIdx) :=
  bit.index.cast (by simp [h])

def hasNext {startIdx : Nat} (bit : BoundedIterator startIdx) : Bool := bit.it.hasNext

def next {startIdx : Nat} (bit : BoundedIterator startIdx) (h : bit.hasNext) : BoundedIterator startIdx :=
  let it' := bit.it.next' h
  have ge' : startIdx ≤ it'.pos.byteIdx := Nat.le_of_lt (Nat.lt_of_le_of_lt bit.ge bit.it.lt_next)
  have le' : it'.pos ≤ it'.toString.endPos := bit.it.next_le_endPos h
  ⟨it', ge', le'⟩

def curr {startIdx : Nat} (bit : BoundedIterator startIdx) (h : bit.hasNext) : Char := bit.it.curr' h

theorem next_maxIdx {startIdx : Nat} (bit : BoundedIterator startIdx) (h : bit.hasNext) : (bit.next h).maxIdx = bit.maxIdx := rfl

def remainingBytes {startIdx : Nat} (bit : BoundedIterator startIdx) : Nat := bit.it.remainingBytes

theorem next_remainingBytes_lt {startIdx : Nat} (bit : BoundedIterator startIdx) (h : bit.hasNext) : (bit.next h).remainingBytes < bit.remainingBytes := by
  simp [next, remainingBytes]

end BoundedIterator

structure StackEntry (σ : Strategy) (nfa : NFA) (startIdx maxIdx : Nat) where
  update : σ.Update
  state : Fin nfa.nodes.size
  it : BoundedIterator startIdx
  eq : it.maxIdx = maxIdx

def captureNextAux (σ : Strategy) (nfa : NFA) (wf : nfa.WellFormed) (startIdx maxIdx : Nat)
  (visited : BitMatrix nfa.nodes.size (maxIdx + 1 - startIdx)) (stack : List (StackEntry σ nfa startIdx maxIdx)) :
  (Option σ.Update × BitMatrix nfa.nodes.size (maxIdx + 1 - startIdx)) :=
  match stack with
  | [] => (.none, visited)
  | ⟨update, state, it, eq⟩ :: stack' =>
    if h : visited.get state (it.index' eq) then
      captureNextAux σ nfa wf startIdx maxIdx visited stack'
    else
      let visited' := visited.set state (it.index' eq)
      have : nfa.nodes.size * (maxIdx + 1 - startIdx) + 1 - visited'.popcount < nfa.nodes.size * (maxIdx + 1 - startIdx) + 1 - visited.popcount :=
        BitMatrix.popcount_decreasing visited state (it.index' eq) h
      match hn : nfa[state] with
      | .done => (.some update, visited')
      | .fail => (.none, visited')
      | .epsilon state' =>
        have isLt : state' < nfa.nodes.size := wf.inBounds' state hn
        captureNextAux σ nfa wf startIdx maxIdx visited' (⟨update, ⟨state', isLt⟩, it, eq⟩ :: stack')
      | .split state₁ state₂ =>
        have isLt : state₁ < nfa.nodes.size ∧ state₂ < nfa.nodes.size := wf.inBounds' state hn
        captureNextAux σ nfa wf startIdx maxIdx visited' (⟨update, ⟨state₁, isLt.1⟩, it, eq⟩ :: ⟨update, ⟨state₂, isLt.2⟩, it, eq⟩ :: stack')
      | .save offset state' =>
        have isLt : state' < nfa.nodes.size := wf.inBounds' state hn
        let update' := σ.write update offset it.pos
        captureNextAux σ nfa wf startIdx maxIdx visited' (⟨update', ⟨state', isLt⟩, it, eq⟩ :: stack')
      | .anchor a state' =>
        have isLt : state' < nfa.nodes.size := wf.inBounds' state hn
        if a.test it.it then
          captureNextAux σ nfa wf startIdx maxIdx visited' (⟨update, ⟨state', isLt⟩, it, eq⟩ :: stack')
        else
          captureNextAux σ nfa wf startIdx maxIdx visited' stack'
      | .char c state' =>
        have isLt : state' < nfa.nodes.size := wf.inBounds' state hn
        if h : it.hasNext then
          if it.curr h = c then
            captureNextAux σ nfa wf startIdx maxIdx visited' (⟨update, ⟨state', isLt⟩, it.next h, eq ▸ it.next_maxIdx h⟩ :: stack')
          else
            captureNextAux σ nfa wf startIdx maxIdx visited' stack'
        else
          captureNextAux σ nfa wf startIdx maxIdx visited' stack'
      | .sparse cs state' =>
        have isLt : state' < nfa.nodes.size := wf.inBounds' state hn
        if h : it.hasNext then
          if it.curr h ∈ cs then
            captureNextAux σ nfa wf startIdx maxIdx visited' (⟨update, ⟨state', isLt⟩, it.next h, eq ▸ it.next_maxIdx h⟩ :: stack')
          else
            captureNextAux σ nfa wf startIdx maxIdx visited' stack'
        else
          captureNextAux σ nfa wf startIdx maxIdx visited' stack'
termination_by (nfa.nodes.size * (maxIdx + 1 - startIdx) + 1 - visited.popcount, stack)

def captureNext (σ : Strategy) (nfa : NFA) (wf : nfa.WellFormed) (it : Iterator) : Option σ.Update :=
  let startIdx := it.pos.byteIdx
  if le : it.pos ≤ it.toString.endPos then
    let bit : BoundedIterator startIdx := ⟨it, Nat.le_refl _, le⟩
    (go startIdx bit (BitMatrix.zero _ _)).1
  else
    .none
where
  go (startIdx : Nat) (bit : BoundedIterator startIdx) (visited : BitMatrix nfa.nodes.size (bit.maxIdx + 1 - startIdx)) :
  Option σ.Update × BitMatrix nfa.nodes.size (bit.maxIdx + 1 - startIdx) :=
  match captureNextAux σ nfa wf startIdx bit.maxIdx visited [⟨σ.empty, ⟨nfa.start, wf.start_lt⟩, bit, rfl⟩] with
  | (.some update, visited') => (.some update, visited')
  | (.none, visited') =>
    if h : bit.hasNext then
      have : (bit.next h).remainingBytes < bit.remainingBytes := bit.next_remainingBytes_lt h
      go startIdx (bit.next h) visited'
    else
      (.none, visited')
  termination_by bit.remainingBytes

def captureNextBuf (nfa : NFA) (wf : nfa.WellFormed) (bufferSize : Nat) (it : Iterator) : Option (Buffer bufferSize) :=
  let _ := BufferStrategy bufferSize
  captureNext (BufferStrategy bufferSize) nfa wf it

def searchNext (nfa : NFA) (wf : nfa.WellFormed) (it : Iterator) : Option (Pos × Pos) := do
  let slots ← captureNextBuf nfa wf 2 it
  pure (← slots[0], ← slots[1])

end Regex.Backtracker
