(* ================================================================= *)
(* TRACKING_CALC - PHAN TINH TOAN THUAN TUI (KHONG QD75)              *)
(* Tinh: E + FIFO 16 + xoay goc + target + ra DINT.                   *)
(* Dieu khien (Y10/X4/M-code/van keo) nam file khac, doc rTarg*/iState *)
(*  qua bien trung gian. Dieu khien cap iCorner/iPhase/bSegInit vao.  *)
(* Don vi: mm; mm/s; D4010 0.1do -> radian; 0.1um = mm*10000.0;        *)
(*  dt = 0.01; nua canh 20.0; don dau 0.8s; X/Y 0..170; Z 0..50.      *)
(* ================================================================= *)

(* ---- PHAN A: INIT + M500 + THUOC DAY E + FIFO 16 ---- *)

(* 1. INIT - SM402 xung 1 scan dau sau RUN *)
IF SM402 OR NOT bInit THEN
    bInit := TRUE;
    bPrevTrig := FALSE;
    bPrevEn := FALSE;
    rEncDist := 0.0;
    rBelt := 0.0;
    rBeltF := 0.0;
    rAlpha := 1.0;
    rDt := 0.01;
    rLeadT := 0.8;
    iHead := 0;
    iTail := 0;
    iCnt := 0;
    bActive := FALSE;
    bQFull := FALSE;
    iState := 0;
    iCorner := 1;
    rPartX0 := 0.0;
    rPartY0 := 0.0;
    rPartAng := 0.0;
    rPartE0 := 0.0;
END_IF;
(* 1b. M500: canh len reset sach; OFF dung *)
IF M500 AND NOT bPrevEn THEN
    rEncDist := 0.0;
    rBelt := 0.0;
    rBeltF := 0.0;
    iHead := 0;
    iTail := 0;
    iCnt := 0;
    bActive := FALSE;
    bQFull := FALSE;
    iState := 0;
    iCorner := 1;
    bPrevTrig := FALSE;
END_IF;
bPrevEn := M500;
IF NOT M500 THEN
    bActive := FALSE;
    iState := 0;
END_IF;
(* 2. THUOC DAY E - doc live D4000 moi scan *)
rBelt := INT_TO_REAL(D4000);
rBeltF := rBeltF + ((rBelt - rBeltF) * rAlpha);
rEncDist := rEncDist + (rBelt * rDt);
(* 3-4. FIFO - chi chay khi M500 ON *)
IF M500 THEN
    IF M1000 AND NOT bPrevTrig THEN
        IF iCnt < 16 THEN
            qPX[iTail] := INT_TO_REAL(D1000);
            qPY[iTail] := INT_TO_REAL(D2000);
            qPAng[iTail] := (INT_TO_REAL(D4010) / 10.0) * 0.0174532925;
            qPE[iTail] := rEncDist;
            iTail := (iTail + 1) MOD 16;
            iCnt := iCnt + 1;
        ELSE
            bQFull := TRUE;
        END_IF;
    END_IF;
    bPrevTrig := M1000;
    IF (NOT bActive) AND (iCnt > 0) THEN
        rPartX0 := qPX[iHead];
        rPartY0 := qPY[iHead];
        rPartAng := qPAng[iHead];
        rPartE0 := qPE[iHead];
        iHead := (iHead + 1) MOD 16;
        iCnt := iCnt - 1;
        bActive := TRUE;
        iCorner := 1;
        iState := 10;
    END_IF;
    IF iCnt < 16 THEN
        bQFull := FALSE;
    END_IF;
    IF (NOT bActive) AND (iCnt = 0) THEN
        rEncDist := 0.0;
        rBeltF := 0.0;
    END_IF;
END_IF;

(* ---- PHAN B: XOAY GOC + MUC TIEU + RA DINT ---- *)
(* Vao tu Phan A: rPartX0/rPartY0 (mm), rPartE0 (mm), rPartAng (rad),   *)
(*  rEncDist (mm), rBeltF (mm/s), rLeadT (s), iCorner (1..4).           *)
(* Vao tu slice dieu khien: iPhase (1 bay / 2 ha-phun / 3 nhac),        *)
(*  bSegInit (xung 1 scan dau moi doan -> chot rLast).                  *)
(* Doc thang: D3000 Zbay 0.1mm, D3001 Zcham 0.1mm, D4002 master,        *)
(*  D4004 tran. Ra: rTarg* (mm, da kep), dTarg (D1010/D2010/D3010),     *)
(*  dStart (D1020/D2020/D3020, tu rLast), dSpdStg (D4020),              *)
(*  wMotionType = 1 (D4030). Chi tinh toan.                            *)

(* Zbay/Zcham 0.1mm -> mm *)
IF D3000 > 0 THEN
    rZbay := INT_TO_REAL(D3000) / 10.0;
ELSE
    rZbay := 10.0;
END_IF;
IF D3001 > 0 THEN
    rZcham := INT_TO_REAL(D3001) / 10.0;
ELSE
    rZcham := 40.0;
END_IF;
IF rZbay < 0.0 THEN
    rZbay := 0.0;
END_IF;
IF rZbay > 50.0 THEN
    rZbay := 50.0;
END_IF;
IF rZcham < 0.0 THEN
    rZcham := 0.0;
END_IF;
IF rZcham > 50.0 THEN
    rZcham := 50.0;
END_IF;

(* Master + tran toc do *)
rMaster := INT_TO_REAL(D4002);
IF rMaster <= 0.0 THEN
    rMaster := 10000.0;
END_IF;
rSpdMax := INT_TO_REAL(D4004);
IF rSpdMax <= 0.0 THEN
    rSpdMax := 20000.0;
END_IF;

(* Don dau: mac dinh 0.8 s neu chua cai *)
IF rLeadT <= 0.0 THEN
    rLeadT := 0.8;
END_IF;

(* Chon goc vuong chua xoay theo iCorner (nua canh 20.0 mm) *)
CASE iCorner OF
    1:
        rDx0 := 0.0 - 20.0;
        rDy0 := 0.0 - 20.0;
    2:
        rDx0 := 20.0;
        rDy0 := 0.0 - 20.0;
    3:
        rDx0 := 20.0;
        rDy0 := 20.0;
    4:
        rDx0 := 0.0 - 20.0;
        rDy0 := 20.0;
    ELSE
        rDx0 := 0.0 - 20.0;
        rDy0 := 0.0 - 20.0;
END_CASE;

(* Ma tran xoay (GX Works2: 3 tham so) *)
COS_E(TRUE, rPartAng, rCosVal);
SIN_E(TRUE, rPartAng, rSinVal);
rDxRot := (rDx0 * rCosVal) - (rDy0 * rSinVal);
rDyRot := (rDx0 * rSinVal) + (rDy0 * rCosVal);

(* Target X/Y: tam + do truot bang tai + don dau toc + offset xoay *)
rTargX := rPartX0 + (rEncDist - rPartE0) + (rBeltF * rLeadT) + rDxRot;
rTargY := rPartY0 + rDyRot;

(* Target Z + toc do theo pha: 1 bay / 2 ha-phun / 3 nhac *)
CASE iPhase OF
    1:
        rTargZ := rZbay;
        rSpd := rMaster * 0.6;
    2:
        rTargZ := rZcham;
        rSpd := rMaster * 0.12;
    3:
        rTargZ := rZbay;
        rSpd := rMaster * 0.3;
    ELSE
        rTargZ := rZbay;
        rSpd := rMaster * 0.6;
END_CASE;
IF rSpd > rSpdMax THEN
    rSpd := rSpdMax;
END_IF;

(* Kep bien mm: X/Y 0..170, Z 0..50 *)
IF rTargX < 0.0 THEN
    rTargX := 0.0;
END_IF;
IF rTargX > 170.0 THEN
    rTargX := 170.0;
END_IF;
IF rTargY < 0.0 THEN
    rTargY := 0.0;
END_IF;
IF rTargY > 170.0 THEN
    rTargY := 170.0;
END_IF;
IF rTargZ < 0.0 THEN
    rTargZ := 0.0;
END_IF;
IF rTargZ > 50.0 THEN
    rTargZ := 50.0;
END_IF;

(* Chot rLast dau moi doan (bSegInit: xung 1 scan tu slice dieu khien) *)
IF bSegInit THEN
    rLastX := rTargX;
    rLastY := rTargY;
    rLastZ := rTargZ;
END_IF;

(* Ra 32-bit 0.1um + toc do + loai chuyen dong *)
dTargX_01um := REAL_TO_DINT(rTargX * 10000.0);
dTargY_01um := REAL_TO_DINT(rTargY * 10000.0);
dTargZ_01um := REAL_TO_DINT(rTargZ * 10000.0);
dStartX_01um := REAL_TO_DINT(rLastX * 10000.0);
dStartY_01um := REAL_TO_DINT(rLastY * 10000.0);
dStartZ_01um := REAL_TO_DINT(rLastZ * 10000.0);
dSpdStg := REAL_TO_DINT(rSpd);
wMotionType := 1;
