import Regex.Data.BoundedIterator
import RegexCorrectness.Data.String

set_option autoImplicit false

open String (Iterator)

namespace Regex.Data.BoundedIterator

variable {startIdx maxIdx : Nat}

@[ext]
theorem ext_pos {bit₁ bit₂ : BoundedIterator startIdx maxIdx} (h₁ : bit₁.toString = bit₂.toString) (h₂ : bit₁.pos = bit₂.pos) : bit₁ = bit₂ := by
  simp [BoundedIterator.ext_iff, Iterator.ext_iff]
  exact ⟨h₁, h₂⟩

@[ext]
theorem ext_index {bit₁ bit₂ : BoundedIterator startIdx maxIdx} (h₁ : bit₁.toString = bit₂.toString) (h₂ : bit₁.index = bit₂.index) : bit₁ = bit₂ := by
  simp [BoundedIterator.ext_pos_iff, h₁]
  simp [index, String.Pos.ext_iff] at h₂
  simp [String.Pos.ext_iff]
  calc bit₁.pos.byteIdx
    _ = bit₂.pos.byteIdx - startIdx + startIdx := Nat.eq_add_of_sub_eq bit₁.ge h₂
    _ = bit₂.pos.byteIdx := Nat.sub_add_cancel bit₂.ge

theorem next_toString {bit : BoundedIterator startIdx maxIdx} (h : bit.hasNext) : (bit.next h).toString = bit.toString := by
  simp [next, Iterator.next', BoundedIterator.toString]

theorem valid_of_it_valid {bit : BoundedIterator startIdx maxIdx} (v : bit.it.Valid) : bit.Valid := v.isValid

theorem valid_of_valid {bit : BoundedIterator startIdx maxIdx} (v : bit.Valid) : bit.it.Valid := Iterator.Valid.of_isValid v

theorem next_valid {bit : BoundedIterator startIdx maxIdx} (h : bit.hasNext) (v : bit.Valid) : (bit.next h).Valid := by
  apply valid_of_it_valid
  simp [next, String.Iterator.next'_eq_next]
  exact (bit.valid_of_valid v).next h

def ValidFor (l r : List Char) (bit : BoundedIterator startIdx maxIdx) : Prop := bit.it.ValidFor l r

namespace ValidFor

theorem hasNext {l r} {bit : BoundedIterator startIdx maxIdx} (vf : ValidFor l r bit) : bit.hasNext ↔ r ≠ [] := by
  unfold ValidFor at vf
  exact vf.hasNext

theorem next {l c r} {bit : BoundedIterator startIdx maxIdx} (vf : ValidFor l (c :: r) bit) : ValidFor (c :: l) r (bit.next (by simp [vf.hasNext])) := by
  unfold ValidFor at vf
  exact vf.next

theorem next' {l r} {bit : BoundedIterator startIdx maxIdx} (h : bit.hasNext) (vf : ValidFor l r bit) : ∃ c r', ValidFor (c :: l) r' (bit.next h) := by
  match r with
  | [] => simp [vf.hasNext] at h
  | c :: r' => exact ⟨c, r', vf.next⟩

theorem curr {l c r} {bit : BoundedIterator startIdx maxIdx} (vf : ValidFor l (c :: r) bit) : bit.curr (by simp [vf.hasNext]) = c := by
  simp [BoundedIterator.curr, bit.it.curr'_eq_curr, String.Iterator.ValidFor.curr vf]

end ValidFor

namespace Valid

theorem validFor {bit : BoundedIterator startIdx maxIdx} (v : bit.Valid) : ∃ l r, ValidFor l r bit :=
  (bit.valid_of_valid v).validFor

theorem validFor_of_hasNext {bit : BoundedIterator startIdx maxIdx} (h : bit.hasNext) (v : bit.Valid) :
  ∃ l r, ValidFor l (bit.curr h :: r) bit := by
  have ⟨l, r, vf⟩ := validFor v
  match h' : r with
  | [] => simp [vf.hasNext] at h
  | c :: r' => exact ⟨l, r', by simpa [vf.curr] using vf⟩

end Valid

end Regex.Data.BoundedIterator
