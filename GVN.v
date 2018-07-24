Require Import Bool.
Require Import Sorting.Permutation.
Require Import Omega.
Require Import sflib.

Require Import Common.
Require Import Value.
Require Import Lang.
Require Import Memory.
Require Import State.
Require Import LoadStore.
Require Import SmallStep.
Require Import Refinement.
Require Import TwinExecution.

Module Ir.

Module GVN.

Inductive physicalized_ptr: Ir.Memory.t -> Ir.val -> Ir.val -> Prop :=
| ps_base:
    forall m p1 p2
           (HP2:Some p2 = Ir.ptr_to_phy m p1),
      physicalized_ptr m (Ir.ptr p1) (Ir.ptr p2)
| ps_gep:
    forall m p1 p2 idx t inb p1' p2'
           (HBASE:physicalized_ptr m (Ir.ptr p1) (Ir.ptr p2))
           (HP1':p1' = Ir.SmallStep.gep p1 idx t m inb)
           (HP2':p2' = Ir.SmallStep.gep p2 idx t m inb),
      physicalized_ptr m p1' p2'.


Lemma eq_update_reg_and_incrpc2:
  forall md1 md2 st r v i1 i2
      (HINST1: Some i1 = Ir.Config.cur_inst md1 st)
      (HINST2: Some i2 = Ir.Config.cur_inst md2 st),
    Ir.Config.eq
      (Ir.SmallStep.update_reg_and_incrpc md1 st r v)
      (Ir.SmallStep.update_reg_and_incrpc md2 st r v).
Proof.
  intros.
  unfold Ir.Config.cur_inst in HINST1.
  unfold Ir.Config.cur_inst in HINST2.
  split.
  { unfold Ir.SmallStep.update_reg_and_incrpc.
    unfold Ir.SmallStep.incrpc.
    des_ifs;
      repeat (rewrite Ir.Config.m_update_pc);
      unfold Ir.Config.update_rval; des_ifs.
  }
  split.
  { unfold Ir.Config.cur_fdef_pc in HINST1.
    unfold Ir.Config.cur_fdef_pc in HINST2.
    des_ifs.
    unfold Ir.IRFunction.get_inst in HINST1.
    unfold Ir.IRFunction.get_inst in HINST2.
    destruct p1; try congruence.
    des_ifs.
    unfold Ir.SmallStep.update_reg_and_incrpc.
    unfold Ir.SmallStep.incrpc.
    rewrite Ir.Config.cur_fdef_pc_update_rval.
    rewrite Ir.Config.cur_fdef_pc_update_rval.
    unfold Ir.Config.cur_fdef_pc.
    rewrite Heq0.
    rewrite Heq1.
    rewrite Heq2.
    rewrite Heq3.
    unfold Ir.IRFunction.next_trivial_pc.
    rewrite Heq5.
    rewrite Heq.
    rewrite Heq6.
    rewrite Heq4.
    apply Ir.Stack.eq_refl.
  }
  split.
  { unfold Ir.SmallStep.update_reg_and_incrpc.
    unfold Ir.SmallStep.incrpc.
    des_ifs;
      unfold Ir.Config.update_pc; unfold Ir.Config.update_rval;
      des_ifs.
  }
  { unfold Ir.SmallStep.update_reg_and_incrpc.
    unfold Ir.SmallStep.incrpc.
    des_ifs;
      unfold Ir.Config.update_pc; unfold Ir.Config.update_rval;
      des_ifs.
  }
Qed.

Lemma physicalized_ptr_nonlog:
  forall m p1 p2
         (HPP:physicalized_ptr m (Ir.ptr p1) (Ir.ptr p2)),
    ~ exists l o, p2 = Ir.plog l o.
Proof.
  intros.
  remember (Ir.ptr p1) as v1.
  remember (Ir.ptr p2) as v2.
  generalize dependent p1.
  generalize dependent p2.
  induction HPP.
  { intros. inv Heqv1. inv Heqv2.
    unfold Ir.ptr_to_phy in HP2.
    destruct p3.
    { unfold Ir.log_to_phy in HP2.
      destruct (Ir.Memory.get m b).
      { intros HH. destruct HH. destruct H. rewrite H in HP2.
        congruence. }
      { congruence. }
    }
    { intros HH. destruct HH. destruct H. rewrite H in HP2.
      congruence. }
  }
  { intros. inv Heqv1. inv Heqv2.
    intros HH.
    destruct HH. destruct H0. rewrite H0 in H1.
    eapply IHHPP.
    reflexivity. reflexivity.
    unfold Ir.SmallStep.gep in H1.
    destruct p2.
    { destruct inb.
      { destruct (Ir.Memory.get m b) eqn:HGET.
        destruct (Ir.MemBlock.inbounds n t0 &&
         Ir.MemBlock.inbounds
           (Ir.SmallStep.twos_compl_add n (idx * Ir.ty_bytesz t) Ir.MEMSZ) t0)
                 eqn:HINB.
        eexists. eexists. reflexivity.
        eexists. eexists. reflexivity.
        eexists. eexists. reflexivity. }
      { eexists. eexists . reflexivity. }
    }
    { destruct inb.
      { des_ifs. }
      { congruence. }
    }
  }
Qed.

(* this was needed because des_ifs made infinite loop. :( *)
Lemma ir_ptr_pphy_inj:
  forall o1 I1 cid1 o2 I2 cid2
         (H:Ir.ptr (Ir.pphy o1 I1 cid1) = Ir.ptr (Ir.pphy o2 I2 cid2)),
    o1 = o2 /\ I1 = I2 /\ cid1 = cid2.
Proof.
  intros.
  inv H.
  split. reflexivity. split. reflexivity. reflexivity.
Qed.

Lemma ir_ptr_plog_inj:
  forall l1 o1 l2 o2
         (H:Ir.ptr (Ir.plog l1 o1) = Ir.ptr (Ir.plog l2 o2)),
    l1 = l2 /\ o1 = o2.
Proof.
  intros.
  inv H.
  split. reflexivity. split.
Qed.

Lemma physicalized_ptr_phy:
  forall m o1 Is1 cid1 o2 Is2 cid2 v1 v2
         (HPP:physicalized_ptr m v1 v2)
         (HV1:v1 = Ir.ptr (Ir.pphy o1 Is1 cid1))
         (HV2:v2 = Ir.ptr (Ir.pphy o2 Is2 cid2)),
    o1 = o2 /\ lsubseq Is1 Is2 /\ cid2 = None.
Proof.
  intros.
  generalize dependent o1.
  generalize dependent Is1.
  generalize dependent cid1.
  generalize dependent o2.
  generalize dependent Is2.
  generalize dependent cid2.
  induction HPP.
  { intros.
    inv HV1.
    unfold Ir.ptr_to_phy in HP2. inv HP2.
    inv HV2.
    split. reflexivity.
    split. constructor.
    reflexivity.
  }
  { intros.
    destruct p2'; try congruence.
    destruct p1'; try congruence.
    inv HV2.
    inv HV1.
    destruct p2.
    { eapply physicalized_ptr_nonlog in HPP.
      exfalso. apply HPP. eexists. eexists. reflexivity.
    }
    { unfold Ir.SmallStep.gep in HP1'.
      
      destruct p1 eqn:HP;
      destruct inb eqn:HINB.
      destruct (Ir.Memory.get m b) eqn:HGET.
      destruct (Ir.MemBlock.inbounds n0 t0 &&
           Ir.MemBlock.inbounds
             (Ir.SmallStep.twos_compl_add n0 (idx * Ir.ty_bytesz t) Ir.PTRSZ) t0)
               eqn:HINB2.
      ss.
      ss.
      ss.
      congruence.
      destruct (idx * Ir.ty_bytesz t <? Nat.shiftl 1 (Ir.PTRSZ - 1)) eqn:HSHL.
      {
        destruct (n0 + idx * Ir.ty_bytesz t <? Ir.MEMSZ) eqn:HOFS.
        {
          apply ir_ptr_pphy_inj in HP1'.
          destruct HP1'. destruct H0.
          exploit IHHPP.
          { reflexivity. }
          { reflexivity. }
          intros HH. destruct HH. destruct H3.
          unfold Ir.SmallStep.gep in HP2'.
          rewrite HSHL in HP2'.
          destruct (n + idx * Ir.ty_bytesz t <? Ir.MEMSZ) eqn:HN.
          { apply ir_ptr_pphy_inj in HP2'. destruct HP2'.
            split.
            { congruence. }
            split.
            { rewrite H0.
              destruct H6. rewrite H6.
              rewrite H2. constructor. constructor. assumption. }
            { destruct H6. congruence. }
          }
          { ss. }
        }
        { ss. }
      }
      { exploit IHHPP; try reflexivity.
        intros HH.
        inv HH. destruct H0.
        unfold Ir.SmallStep.gep in HP2'.
        apply ir_ptr_pphy_inj in HP1'.
        destruct HP1'. destruct H2.
        rewrite HSHL in HP2'.
        apply ir_ptr_pphy_inj in HP2'.
        destruct HP2'. destruct H5.
        split. congruence.
        split. rewrite H2, H5. constructor. constructor. assumption.
        congruence.
      }
      { exploit IHHPP; try reflexivity.
        intros HH.
        inv HH. destruct H0.
        unfold Ir.SmallStep.gep in HP2'.
        apply ir_ptr_pphy_inj in HP2'.
        destruct HP2'. destruct H2.
        apply ir_ptr_pphy_inj in HP1'.
        destruct HP1'. destruct H5.
        split. congruence. split. congruence. congruence.
      }
    }
  }
Qed.

Lemma PTRSZ_MEMSZ:
  Nat.shiftl 2 (Ir.PTRSZ - 1) = Ir.MEMSZ.
Proof. reflexivity. Qed.

Lemma MEMSZ_nonzero:
Ir.MEMSZ <> 0.
Proof.
  unfold Ir.MEMSZ.
  unfold Ir.PTRSZ.
  intros HH. simpl in HH.
  repeat (rewrite Nat.double_twice in HH).
  omega.
Qed.

Opaque Ir.PTRSZ.
Opaque Ir.MEMSZ.

Lemma physicalized_ptr_log:
  forall m l1 o1 o2 Is2 cid2 v1 v2 mb
         (HPP:physicalized_ptr m v1 v2)
         (HV1:v1 = Ir.ptr (Ir.plog l1 o1))
         (HV2:v2 = Ir.ptr (Ir.pphy o2 Is2 cid2))
         (HGET:Some mb = Ir.Memory.get m l1),
    (Ir.MemBlock.addr mb + o1) mod Ir.MEMSZ = o2.
Proof.
  intros.
  generalize dependent l1.
  generalize dependent o1.
  generalize dependent o2.
  generalize dependent Is2.
  generalize dependent cid2.
  generalize dependent mb.
  induction HPP.
  { intros.
    inv HV1.
    unfold Ir.ptr_to_phy in HP2. inv HP2.
    inv HV2.
    unfold Ir.log_to_phy in H0.
    rewrite <- HGET in H0.
    congruence.
  }
  { intros.
    destruct p2'; try congruence.
    destruct p1'; try congruence.
    inv HV2.
    inv HV1.
    destruct p2.
    { eapply physicalized_ptr_nonlog in HPP.
      exfalso. apply HPP. eexists. eexists. reflexivity.
    }
    { unfold Ir.SmallStep.gep in HP1'.
      destruct p1 eqn:HP.
      { (* log *)
        destruct inb eqn:HINB.
        { (* inbounds *)
          destruct (Ir.Memory.get m b) eqn:HGETB; try ss.
          exploit IHHPP.
          { reflexivity. }
          { reflexivity. }
          { rewrite HGETB. reflexivity. }
          intros HH.
          unfold Ir.SmallStep.gep in HP2'.
          destruct ((idx * (Ir.ty_bytesz t) <?
                     Nat.shiftl 1 (Ir.PTRSZ - 1))) eqn:H11.
          { (* positive offset add *)
            destruct (n + idx * Ir.ty_bytesz t <? Ir.MEMSZ) eqn:H2; try congruence.
            apply ir_ptr_pphy_inj in HP2'.
            destruct HP2'. destruct H0.
            rewrite PeanoNat.Nat.ltb_lt in H2.
            destruct (Ir.MemBlock.inbounds n0 t0 &&
                                           Ir.MemBlock.inbounds
             (Ir.SmallStep.twos_compl_add n0 (idx * Ir.ty_bytesz t) Ir.PTRSZ) t0)
                     eqn:HINB2.
            { apply ir_ptr_plog_inj in HP1'. destruct HP1'. subst l1.
              subst o1. subst o2.
              unfold Ir.SmallStep.twos_compl_add.
              unfold Ir.SmallStep.twos_compl.
              rewrite PTRSZ_MEMSZ.
              rewrite Nat.add_mod_idemp_r.
              rewrite <- HH.
              rewrite Nat.add_mod_idemp_l.
              rewrite PeanoNat.Nat.add_assoc.
              rewrite HGETB in HGET. inv HGET. reflexivity.
              apply MEMSZ_nonzero. apply MEMSZ_nonzero.
            }
            { ss. }
          }
        { (* negaitve offset add *)
          destruct (Ir.MemBlock.inbounds n0 t0 &&
           Ir.MemBlock.inbounds
             (Ir.SmallStep.twos_compl_add n0 (idx * Ir.ty_bytesz t) Ir.PTRSZ) t0)
                   eqn:HINB2.
          {
            inv HP2'.
            inv HP1'.
            rewrite HGETB in HGET. inv HGET.
            unfold Ir.SmallStep.twos_compl_add.
            unfold Ir.SmallStep.twos_compl.
            rewrite PTRSZ_MEMSZ.
            rewrite Nat.add_mod_idemp_r.
            rewrite Nat.add_mod_idemp_l.
            rewrite PeanoNat.Nat.add_assoc. reflexivity.
            apply MEMSZ_nonzero. apply MEMSZ_nonzero.
          }
          { ss. }
        }
      }
      { (* no inbounds *)
        unfold Ir.SmallStep.gep in HP2'.
        inv HP2'.
        inv HP1'.
        exploit IHHPP;try reflexivity; try eassumption.
        intros HH. rewrite <- HH.
        unfold Ir.SmallStep.twos_compl_add.
        unfold Ir.SmallStep.twos_compl.
        rewrite PTRSZ_MEMSZ.
        rewrite Nat.add_mod_idemp_r.
        rewrite Nat.add_mod_idemp_l.
        rewrite PeanoNat.Nat.add_assoc. reflexivity.
        apply MEMSZ_nonzero. apply MEMSZ_nonzero.
      }
    }
    { des_ifs. }
    }
  }
Qed.

Lemma and_implies:
  forall (P Q:Prop),
 (P /\ (P -> Q)) -> P /\ Q.
Proof.
  intros.
  destruct H.
  split. assumption. apply H0. apply H.
Qed.

Lemma inbounds_added_abs_true:
  forall m b t0 n0 n ofs
    (wf_m:Ir.Memory.wf m)
    (HGET:Ir.Memory.get m b = Some t0)
    (HPP:(Ir.MemBlock.addr t0 + n0) mod Ir.MEMSZ = n)
    (HINB:Ir.MemBlock.inbounds
         (Ir.SmallStep.twos_compl_add n0 ofs Ir.PTRSZ) t0 = true),
  Ir.MemBlock.inbounds_abs
                      ((n + ofs) mod Ir.MEMSZ) t0 = true.
Proof.
  intros.
  erewrite Ir.MemBlock.inbounds_inbounds_abs in HINB; try reflexivity.
  rewrite <- HPP.
  assert ((Ir.SmallStep.twos_compl_add n0 ofs Ir.PTRSZ
           + Ir.MemBlock.addr t0) =
          ((Ir.MemBlock.addr t0 + n0) mod Ir.MEMSZ + ofs)
            mod Ir.MEMSZ).
  { unfold Ir.SmallStep.twos_compl_add.
    unfold Ir.SmallStep.twos_compl.
    rewrite PTRSZ_MEMSZ.
    rewrite Nat.add_mod_idemp_l.
    rewrite Nat.add_comm.
    rewrite <- Nat.add_assoc with (n := Ir.MemBlock.addr t0).
    rewrite <- Nat.add_mod_idemp_r with (b := (n0 + ofs)).
    rewrite Nat.mod_small with
        (a := (Ir.MemBlock.addr t0 + (n0 + ofs)
                                       mod Ir.MEMSZ)).
    reflexivity.
    { (* Ir.MemBlock.addr t0 + (n0 + idx * Ir.ty_bytesz t)
         mod Ir.MEMSZ < Ir.MEMSZ *)
      unfold Ir.MemBlock.inbounds_abs in HINB.
      unfold in_range in HINB.
      rewrite andb_true_iff in HINB.
      destruct HINB.
      rewrite PeanoNat.Nat.leb_le in H0, H.
      unfold Ir.SmallStep.twos_compl_add in H0.
      unfold Ir.SmallStep.twos_compl in H0.
      rewrite PTRSZ_MEMSZ in H0.
      rewrite Nat.add_comm with (m := Ir.MemBlock.addr t0) in H0.
      assert (fst (Ir.MemBlock.P0_range t0) + snd (Ir.MemBlock.P0_range t0)
              < Ir.MEMSZ).
      { unfold Ir.MemBlock.P0_range.
        simpl.
        destruct wf_m.
        symmetry in HGET.
        eapply Ir.Memory.get_In in HGET;try reflexivity.
        apply wf_blocks in HGET.
        destruct HGET.
        apply wf_inmem.
        unfold Ir.MemBlock.addr.
        destruct (Ir.MemBlock.P t0).
        { simpl in wf_twin. unfold Ir.TWINCNT in wf_twin. congruence. }
        { simpl. left. reflexivity. }
      }
      eapply Nat.le_lt_trans.
      eapply H0.
      eassumption.
    }
    apply MEMSZ_nonzero.
    apply MEMSZ_nonzero.
  }
  rewrite H in HINB.
  assumption.
Qed.

Lemma inbounds_abs_true:
  forall m b t0 n0 n
    (wf_m:Ir.Memory.wf m)
    (HGET:Ir.Memory.get m b = Some t0)
    (HPP:(Ir.MemBlock.addr t0 + n0) mod Ir.MEMSZ = n)
    (HINB:Ir.MemBlock.inbounds n0 t0 = true),
  Ir.MemBlock.inbounds_abs n t0 = true.
Proof.
  intros.
  erewrite Ir.MemBlock.inbounds_inbounds_abs in HINB;
    try reflexivity.
  rewrite <- HPP.
  assert ((Ir.MemBlock.addr t0 + n0) mod Ir.MEMSZ =
          n0 + Ir.MemBlock.addr t0).
  { unfold Ir.MemBlock.inbounds_abs in HINB.
    unfold in_range in HINB.
    rewrite andb_true_iff in HINB.
    destruct HINB.
    rewrite Nat.leb_le in H0.
    unfold Ir.MemBlock.P0_range in H0.
    simpl in H0.
    inv wf_m.
    symmetry in HGET.
    eapply Ir.Memory.get_In in HGET; try reflexivity.
    apply wf_blocks in HGET.
    inv HGET.
    rewrite Nat.mod_small.
    omega.
    eapply Nat.le_lt_trans.
    rewrite Nat.add_comm.
    eassumption.
    eapply wf_inmem.
    unfold Ir.MemBlock.addr.
    destruct (Ir.MemBlock.P t0).
    { simpl in wf_twin. unfold Ir.TWINCNT in wf_twin. omega. }
    { simpl. eauto. }
  }
  rewrite H. assumption.
Qed.

Lemma inbounds_added_abs_true2:
  forall m b t0 n0 n ofs sz
    (wf_m:Ir.Memory.wf m)
    (HGET:Ir.Memory.get m b = Some t0)
    (HPP:(Ir.MemBlock.addr t0 + n0) mod Ir.MEMSZ = n)
    (HINB:Ir.MemBlock.inbounds
         (Ir.SmallStep.twos_compl_add n0 ofs Ir.PTRSZ + sz) t0 = true),
  Ir.MemBlock.inbounds_abs
                      ((n + ofs) mod Ir.MEMSZ + sz) t0 = true.
Proof.
  intros.
  erewrite Ir.MemBlock.inbounds_inbounds_abs in HINB; try reflexivity.
  rewrite <- HPP.
  assert ((Ir.SmallStep.twos_compl_add n0 ofs Ir.PTRSZ
           + Ir.MemBlock.addr t0) =
          ((Ir.MemBlock.addr t0 + n0) mod Ir.MEMSZ + ofs)
            mod Ir.MEMSZ).
  { unfold Ir.SmallStep.twos_compl_add.
    unfold Ir.SmallStep.twos_compl.
    rewrite PTRSZ_MEMSZ.
    rewrite Nat.add_mod_idemp_l.
    rewrite Nat.add_comm.
    rewrite <- Nat.add_assoc with (n := Ir.MemBlock.addr t0).
    rewrite <- Nat.add_mod_idemp_r with (b := (n0 + ofs)).
    rewrite Nat.mod_small with
        (a := (Ir.MemBlock.addr t0 + (n0 + ofs)
                                       mod Ir.MEMSZ)).
    reflexivity.
    { (* Ir.MemBlock.addr t0 + (n0 + idx * Ir.ty_bytesz t)
         mod Ir.MEMSZ < Ir.MEMSZ *)
      unfold Ir.MemBlock.inbounds_abs in HINB.
      unfold in_range in HINB.
      rewrite andb_true_iff in HINB.
      destruct HINB.
      rewrite PeanoNat.Nat.leb_le in H0, H.
      unfold Ir.SmallStep.twos_compl_add in H0.
      unfold Ir.SmallStep.twos_compl in H0.
      rewrite PTRSZ_MEMSZ in H0.
      rewrite Nat.add_comm with (m := Ir.MemBlock.addr t0) in H0.
      assert (fst (Ir.MemBlock.P0_range t0) + snd (Ir.MemBlock.P0_range t0)
              < Ir.MEMSZ).
      { unfold Ir.MemBlock.P0_range.
        simpl.
        destruct wf_m.
        symmetry in HGET.
        eapply Ir.Memory.get_In in HGET;try reflexivity.
        apply wf_blocks in HGET.
        destruct HGET.
        apply wf_inmem.
        unfold Ir.MemBlock.addr.
        destruct (Ir.MemBlock.P t0).
        { simpl in wf_twin. unfold Ir.TWINCNT in wf_twin. congruence. }
        { simpl. left. reflexivity. }
      }
      eapply Nat.le_lt_trans.
      eapply Nat.le_trans with (m := Ir.MemBlock.addr t0 + ((n0 + ofs) mod Ir.MEMSZ + sz)).
      omega.
      eapply H0.
      eassumption.
    }
    apply MEMSZ_nonzero.
    apply MEMSZ_nonzero.
  }
  rewrite <- Nat.add_assoc in HINB.
  rewrite Nat.add_comm with (n := sz) in HINB.
  rewrite Nat.add_assoc in HINB.
  rewrite H in HINB.
  assumption.
Qed.

Lemma inbounds_abs_true2:
  forall m b t0 n0 n sz
    (wf_m:Ir.Memory.wf m)
    (HGET:Ir.Memory.get m b = Some t0)
    (HPP:(Ir.MemBlock.addr t0 + n0) mod Ir.MEMSZ = n)
    (HINB:Ir.MemBlock.inbounds (n0 + sz) t0 = true),
  Ir.MemBlock.inbounds_abs (n + sz) t0 = true.
Proof.
  intros.
  erewrite Ir.MemBlock.inbounds_inbounds_abs in HINB;
    try reflexivity.
  rewrite <- HPP.
  assert ((Ir.MemBlock.addr t0 + n0) mod Ir.MEMSZ =
          n0 + Ir.MemBlock.addr t0).
  { unfold Ir.MemBlock.inbounds_abs in HINB.
    unfold in_range in HINB.
    rewrite andb_true_iff in HINB.
    destruct HINB.
    rewrite Nat.leb_le in H0.
    unfold Ir.MemBlock.P0_range in H0.
    simpl in H0.
    inv wf_m.
    symmetry in HGET.
    eapply Ir.Memory.get_In in HGET; try reflexivity.
    apply wf_blocks in HGET.
    inv HGET.
    rewrite Nat.mod_small.
    omega.
    eapply Nat.le_lt_trans.
    rewrite Nat.add_comm.
    eapply Nat.le_trans with (m := n0 + sz + Ir.MemBlock.addr t0).
    omega.
    eassumption.
    eapply wf_inmem.
    unfold Ir.MemBlock.addr.
    destruct (Ir.MemBlock.P t0).
    { simpl in wf_twin. unfold Ir.TWINCNT in wf_twin. omega. }
    { simpl. eauto. }
  }
  rewrite H.
  rewrite <- Nat.add_assoc.
  rewrite Nat.add_comm with (m := sz).
  rewrite Nat.add_assoc.
  assumption.
Qed.

Lemma inbounds_tcadd_abs:
  forall m b t0 ofs n n0
    (wf_m:Ir.Memory.wf m)
    (HGET:Ir.Memory.get m b = Some t0)
    (HINB:Ir.MemBlock.inbounds
            (Ir.SmallStep.twos_compl_add n ofs Ir.PTRSZ) t0 = true)
    (HPP:(Ir.MemBlock.addr t0 + n) mod Ir.MEMSZ = n0),
  Ir.MemBlock.inbounds_abs
      (Ir.SmallStep.twos_compl_add n0 ofs Ir.PTRSZ) t0 = true.
Proof.
  intros.
  unfold Ir.SmallStep.twos_compl_add.
  unfold Ir.SmallStep.twos_compl.
  eapply inbounds_added_abs_true; try eassumption.
Qed.

(* Very important lemma. *)
Lemma physicalized_ptr_log_I:
  forall v1 v2 m
         (HPP:physicalized_ptr m v1 v2),
    forall md l1 o1 o2 I2 cid2 mb st
         (HM:m = Ir.Config.m st)
         (HWF:Ir.Config.wf md st)
         (HV1:v1 = Ir.ptr (Ir.plog l1 o1))
         (HV2:v2 = Ir.ptr (Ir.pphy o2 I2 cid2))
         (HGET:Some mb = Ir.Memory.get (Ir.Config.m st) l1),
    List.forallb (fun i => Ir.MemBlock.inbounds_abs i mb) I2 = true.
Proof.
  intros v1 v2 st HPP.
  induction HPP.
  { intros.
    unfold Ir.ptr_to_phy in HP2.
    destruct p1.
    { unfold Ir.log_to_phy in HP2.
      inv HV1.
      rewrite <- HGET in HP2.
      inv HP2.
      inv HV2. reflexivity. }
    { inv HP2. inv HV2. reflexivity. }
  }
  { intros.
    inv HV1.
    inv HV2.
    unfold Ir.SmallStep.gep in H.
    des_ifs.
    { unfold Ir.SmallStep.gep in H1.
      des_ifs.
      { rewrite Heq in HGET. inv HGET. symmetry in Heq.
        simpl.
        dup HWF. inv HWF.
        eapply physicalized_ptr_log in HPP; try eassumption; try reflexivity.
        rewrite andb_true_iff in Heq0.
        destruct Heq0.
        rewrite <- HPP.
        symmetry in Heq.
        erewrite inbounds_abs_true with (n0 := n); try eassumption; try reflexivity.
        erewrite inbounds_tcadd_abs; try eassumption; try reflexivity.
        erewrite IHHPP; try reflexivity; try eassumption.
        congruence.
      }
      { rewrite Heq in HGET. inv HGET. symmetry in Heq.
        simpl.
        dup HWF. inv HWF.
        eapply physicalized_ptr_log in HPP; try eassumption; try reflexivity.
        rewrite andb_true_iff in Heq0.
        destruct Heq0.
        rewrite <- HPP.
        symmetry in Heq.
        erewrite inbounds_abs_true with (n0 := n); try eassumption; try reflexivity.
        erewrite inbounds_tcadd_abs; try eassumption; try reflexivity.
        erewrite IHHPP; try reflexivity; try eassumption.
        congruence.
      }
    }
    { unfold Ir.SmallStep.gep in H1.
      des_ifs.
      erewrite IHHPP; try reflexivity; try eassumption.
    }
  }
Qed.

(* NOTE: This lemma does not hold anymore if function call is introduced.
 This lemma should be replaced with something else which gives criteria
 to cid. (ex: cid is never bogus) *)
Lemma physicalized_ptr_log_cid:
  forall v1 v2 m
         (HPP:physicalized_ptr m v1 v2),
    forall md l1 o1 o2 I2 cid2 mb st
         (HM:m = Ir.Config.m st)
         (HWF:Ir.Config.wf md st)
         (HV1:v1 = Ir.ptr (Ir.plog l1 o1))
         (HV2:v2 = Ir.ptr (Ir.pphy o2 I2 cid2))
         (HGET:Some mb = Ir.Memory.get (Ir.Config.m st) l1),
      cid2 = None.
Proof.
  intros v1 v2 m HPP.
  induction HPP.
  { intros. inv HV1. inv HV2. unfold Ir.ptr_to_phy in HP2.
    unfold Ir.log_to_phy in HP2.
    des_ifs.
  }
  { intros. inv HV1. inv HV2.
    unfold Ir.SmallStep.gep in *.
    des_ifs.
    { eapply IHHPP.
      reflexivity. eassumption. reflexivity. reflexivity. eassumption. }
    { eapply IHHPP.
      reflexivity. eassumption. reflexivity. reflexivity. eassumption. }
    { eapply IHHPP.
      reflexivity. eassumption. reflexivity. reflexivity. eassumption. }
  }
Qed.

Lemma physicalized_ptr_log_get:
  forall v1 v2 m
         (HPP:physicalized_ptr m v1 v2),
    forall md l1 o1 st
         (HM:m = Ir.Config.m st)
         (HWF:Ir.Config.wf md st)
         (HV1:v1 = Ir.ptr (Ir.plog l1 o1)),
      exists mb, Some mb = Ir.Memory.get (Ir.Config.m st) l1.
Proof.
  intros v1 v2 m HPP.
  induction HPP.
  { intros. inv HV1. unfold Ir.ptr_to_phy in HP2.
    unfold Ir.log_to_phy in HP2.
    des_ifs. eexists. reflexivity.
  }
  { intros. inv HV1.
    unfold Ir.SmallStep.gep in *.
    des_ifs.
    { eapply IHHPP.
      reflexivity. eassumption. reflexivity. }
    { eapply IHHPP.
      reflexivity. eassumption. reflexivity. }
  }
Qed.

Lemma get_deref_physicalized_ptr:
  forall md st sz p1 p2
         (HWF:Ir.Config.wf md st)
         (HSZ:sz> 0)
         (HPP:physicalized_ptr (Ir.Config.m st) (Ir.ptr p1) (Ir.ptr p2)),
    (exists blk, Ir.get_deref (Ir.Config.m st) p1 sz = [blk] /\
                 Ir.get_deref (Ir.Config.m st) p2 sz = [blk]) \/
    (Ir.get_deref (Ir.Config.m st) p1 sz = []).
Proof.
  intros.
  destruct p2.
  { (* p2 is never log -> no *)
    eapply physicalized_ptr_nonlog in HPP.
    exfalso. eapply HPP. eauto. }
  destruct p1.
  { (* p1 is log! *)
    dup HPP.
    dup HPP.
    dup HPP.
    eapply physicalized_ptr_log_get in HPP; try reflexivity; try eassumption.
    destruct HPP.
    eapply physicalized_ptr_log in HPP0; try reflexivity; try eassumption.
    eapply physicalized_ptr_log_I in HPP1; try reflexivity; try eassumption.
    eapply physicalized_ptr_log_cid in HPP2; try reflexivity; try eassumption.
    remember (Ir.get_deref (Ir.Config.m st) (Ir.plog b n0) sz) as res.
    dup Heqres.
    symmetry in Heqres.
    eapply Ir.get_deref_log in Heqres.
    2: rewrite <- H. 2: reflexivity.
    destruct Heqres.
    { (* okay, deref p1 succeeded. *)
      subst res.
      (* b is alive. *)
      dup H0.
      eapply Ir.get_deref_log_alive in H1; try eassumption.
      left. eexists.
      split. eassumption.
      subst o.
      (* prepare to apply get_deref_ptr_phy_same. *)
      remember (Ir.ptr_to_phy (Ir.Config.m st) (Ir.plog b n0)).
      symmetry in Heqo. dup Heqo.
      unfold Ir.ptr_to_phy in Heqo.
      unfold Ir.log_to_phy in Heqo.
      rewrite <- H in Heqo.
      rewrite HPP0 in Heqo.
      rewrite <- Heqo in Heqo0. clear Heqo.
      eapply Ir.get_deref_ptr_phy_same
        with (p' := Ir.pphy n [] None) in H0; try assumption.
      (* time to promote get_deref (pphy n [] None) into
         get_deref (pphy n l None). *)
      eapply Ir.get_deref_phy_I3; try assumption.
      (* well, memory wf.. *)
      inv HWF. assumption.
      inv HWF. assumption.
    }
    { (* Oh, deref p1 failed. *)
      intuition.
    }
  }
  { (* p1 is phy. *)
    dup HPP.
    eapply physicalized_ptr_phy in HPP0; try reflexivity.
    inv HPP0. inv H0.
    (* same here. let's use Ir.get_deref_ptr_phy_same:
       Ir.get_deref m p sz = [bo] ->
       Ir.ptr_to_phy m p = Some p' -> Ir.get_deref m p' sz = [bo]. *)
    remember (Ir.get_deref (Ir.Config.m st) (Ir.pphy n l0 o0) sz) as res.
    dup Heqres.
    symmetry in Heqres0.
    eapply Ir.get_deref_phy_singleton in Heqres0; try omega.
    destruct Heqres0.
    { (* succeeded. *)
      destruct H0.
      destruct H0.
      inv H0. destruct H1. destruct x. destruct p. simpl in H0.
      simpl in H1.
      (* make cid *)
      eapply Ir.get_deref_phy_cid3 in H2; try congruence.
      left. eexists. split. reflexivity.
      eapply Ir.get_deref_phy_I_subseq; try eassumption.
      congruence.
      (* well, memory wf.. *)
      inv HWF. assumption.
      inv HWF. assumption.
    }
    { (* failed. *)
      intuition.
    }
    inv HWF. assumption.
  }
Qed.


Theorem load_refines:
  forall md1 md2 (* md2 is an optimized program *)
         st r retty opptr1 opptr2 v1 v2 sr1 sr2
         (HWF1:Ir.Config.wf md1 st)
         (HWF2:Ir.Config.wf md2 st) (* State st is wellformed on two modules *)
         (* Two loads on a same state(including same PC) *)
         (HINST1:Some (Ir.Inst.iload r retty opptr1) = Ir.Config.cur_inst md1 st)
         (HINST2:Some (Ir.Inst.iload r retty opptr2) = Ir.Config.cur_inst md2 st)
         (* Has a good relation between pointer operands *)
         (HOP1:Ir.Config.get_val st opptr1 = Some v1)
         (HOP2:Ir.Config.get_val st opptr2 = Some v2)
         (HPP:physicalized_ptr (Ir.Config.m st) v1 v2)
         (* And.. have a step. *)
         (HSTEP1:Ir.SmallStep.sstep md1 st sr1)
         (HSTEP2:Ir.SmallStep.sstep md2 st sr2),
    Ir.Refinement.refines_step_res sr2 sr1. (* target refines source *)
Proof.
  intros.
  inv HSTEP1.
  { inv HSTEP2.
    { inv HISTEP; try congruence.
      unfold Ir.SmallStep.inst_det_step in HNEXT.
      rewrite <- HINST1 in HNEXT.
      rewrite HOP1 in HNEXT.
      inv HISTEP0; try congruence.
      unfold Ir.SmallStep.inst_det_step in HNEXT0.
      rewrite <- HINST2 in HNEXT0.
      rewrite HOP2 in HNEXT0.
      inv HWF1.

      (* okay.. time to do induction. *)
      clear wf_cid_to_f.
      clear wf_cid_to_f2.
      clear wf_stack.
      clear wf_no_bogus_ptr.
      clear wf_no_bogus_ptr_mem.
      induction HPP.
      { (* base case *)
        unfold Ir.deref in HNEXT.
        destruct (Ir.get_deref m p1 (Ir.ty_bytesz retty)) eqn:HDEREF1.
        { (* source is UB - it's done .*)
          inv HNEXT. constructor. }
        { inv HNEXT.
          dup HDEREF1.
          eapply Ir.get_deref_singleton in HDEREF0; try assumption.
          {
            destruct HDEREF0; try congruence.
            destruct H. destruct H. inv H.
            dup HDEREF1.
            apply Ir.get_deref_ptr_phy_same with (p' := p2) in HDEREF1;
              try assumption.
            {
              unfold Ir.deref in HNEXT0.
              rewrite HDEREF1 in HNEXT0.
              inv HNEXT0.
              unfold Ir.load_val.
              unfold Ir.load_bytes.
              { rewrite HDEREF1. rewrite HDEREF0.
                destruct x. destruct p.
                constructor.
                { constructor. }
                { eapply eq_update_reg_and_incrpc2; try eassumption. }
              }
            }
            { apply Ir.ty_bytesz_pos. }
            { congruence. }
          }
          { apply Ir.ty_bytesz_pos. }
        }
      }
      { (* a bit more complex case *)
        admit.
      }
    }
    { (* okay, br in target went wrong. *)
      (* br in src shoud also go wrong. *)
      apply Ir.Config.cur_inst_not_cur_terminator in HINST1.
      inv HISTEP; try
       (apply Ir.Config.cur_inst_not_cur_terminator in HINST2;
        congruence).
    }
    { apply Ir.Config.cur_inst_not_cur_terminator in HINST2.
      unfold Ir.SmallStep.t_step in HTSTEP.
      rewrite <- HINST2 in HTSTEP.
      congruence.
    }
  }
  { apply Ir.Config.cur_inst_not_cur_terminator in HINST1.
    unfold Ir.SmallStep.t_step in HTSTEP.
    rewrite <- HINST1 in HTSTEP.
    congruence. }
  { apply Ir.Config.cur_inst_not_cur_terminator in HINST1.
    unfold Ir.SmallStep.t_step in HTSTEP.
    rewrite <- HINST1 in HTSTEP.
    congruence. }
Admitted.
  

End GVN.

End Ir.