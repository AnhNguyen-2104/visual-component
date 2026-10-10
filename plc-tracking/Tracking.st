(* ========================================================================= *)
(* TRACKING BOI KEO 4 GOC - Q06UDEH + QD75D4 U0 (Da.2=0x15) + M-CODE       *)
(* X->T1 Y->T2 Z->T3 | No.1-12: moi goc 3 diem (bay M0/ha M11/nhac M10)    *)
(* DOC D VAO: D1000 Xcam, D2000 Ycam, D4000 vtoc mm/s, D4010 goc 0.1do     *)
(* D3000 Zbay, D3001 Zcham 0.1mm, D4002 master mm/phut, D4004 tran Pr.8    *)
(* RA D 32-bit: D1010/D2010/D3010 cuoi + D1020/D2020/D3020 dau + D4020     *)
(* D4030 MotionType=1 | M2000 van, M3000 full, M3001 timeout               *)
(* Y0 PLC READY: giu ON 1 cho duy nhat moi scan (tranh double-coil)        *)
(* ========================================================================= *)

(* 1. INIT - SM402 xung 1 scan dau sau RUN *)
IF SM402 OR NOT bInit THEN
    bInit := TRUE;
    bPrevTrig := FALSE;
    rEncDist := 0.0;
    rBelt := 0.0; rBeltF := 0.0;
    rAlpha := 1.0;
    rLeadT := 0.8;
    iHead := 0; iTail := 0; iCnt := 0;
    bActive := FALSE;
    iState := 0; iCorner := 1;
    rTmove := 0.0; rTdwell := 0.0;
    rDt := 0.01;
    rHalfSq := 20.0;
    rMoveS := 1.0;
    rDwellS := 0.6;
    rXMin := 0.0; rXMax := 170.0;
    rYMin := 0.0; rYMax := 170.0;
    rZTravel := 10.0;
    rZGlue := 40.0;
    rTargX := 0.0; rTargY := 0.0; rTargZ := 10.0;
    rLastX := 0.0; rLastY := 0.0; rLastZ := 10.0;
    rTimeoutS := 8.0;
    bPosTimeout := FALSE;
    wNo := 1;
    bStartReq := FALSE; bFired := FALSE; bRunning := FALSE; bMOffReq := FALSE;
    wMcode := 0; wTmp := 0;
END_IF;

(* GIU Y0 ON SUOT - CHI 1 CHO DUY NHAT *)
(* M500 ENABLE TRACKING - ON: reset sach + chay; OFF: dung, giu Y0, tat van *)
IF M500 AND NOT bPrevEn THEN
    bInit := FALSE;
    bActive := FALSE;
    iState := 0; iCorner := 1; iCnt := 0;
    iHead := 0; iTail := 0;
    rEncDist := 0.0; rBeltF := 0.0;
    rTmove := 0.0; rTdwell := 0.0;
    bValve := FALSE; bQFull := FALSE; bPosTimeout := FALSE;
    bFired := FALSE; bRunning := FALSE; bStartReq := FALSE; bMOffReq := FALSE;
    dTargX_01um := 0; dTargY_01um := 0; dTargZ_01um := 0;
    dStartX_01um := 0; dStartY_01um := 0; dStartZ_01um := 0;
    dSpdStg := 0;
    wMotionType := 0;
    wNo := 1; wMcode := 0;
END_IF;
bPrevEn := M500;
IF NOT M500 THEN
    bActive := FALSE;
    iState := 0;
    bValve := FALSE;
    bStartReq := FALSE; bFired := FALSE; bRunning := FALSE;
END_IF;
(* CLEAR M TRUOC START - chuan bi Y10 ma X4 con ON thi Cd.7=1 truoc *)
IF M500 AND NOT bFired AND X4 THEN
    bMOffReq := TRUE;
END_IF;

(* 2. DOC D 16-bit VAO THANG *)
rBelt := INT_TO_REAL(D4000);
rBeltF := rBeltF + (rBelt - rBeltF) * rAlpha;
rEncDist := rEncDist + (rBelt * rDt);
IF D3000 > 0 THEN
    rZTravel := INT_TO_REAL(D3000) / 10.0;
ELSE
    rZTravel := 10.0;
END_IF;
IF D3001 > 0 THEN
    rZGlue := INT_TO_REAL(D3001) / 10.0;
ELSE
    rZGlue := 40.0;
END_IF;
IF rZTravel < 0.0 THEN rZTravel := 0.0; END_IF;
IF rZTravel > 50.0 THEN rZTravel := 50.0; END_IF;
IF rZGlue < 0.0 THEN rZGlue := 0.0; END_IF;
IF rZGlue > 50.0 THEN rZGlue := 50.0; END_IF;

(* 2b. DOC D4002/D4004 - MASTER VA TRAN *)
rMaster := INT_TO_REAL(D4002);
IF rMaster <= 0.0 THEN
    rMaster := 10000.0;
END_IF;
rSpdLim := INT_TO_REAL(D4004);
IF rSpdLim <= 0.0 THEN
    rSpdLim := 20000.0;
END_IF;
rFly := rMaster * 0.6;
rDown := rMaster * 0.12;
rUp := rMaster * 0.3;
IF rFly > rSpdLim THEN rFly := rSpdLim; END_IF;
IF rDown > rSpdLim THEN rDown := rSpdLim; END_IF;
IF rUp > rSpdLim THEN rUp := rSpdLim; END_IF;

(* 2c. DOC M TRUC 1 (Md.25 U0\G808) *)
FROM(TRUE, H0, K808, K1, wMcode);

(* 3-5. CHI CHAY KHI M500 ON - OFF THI DUNG, GIU Y0 *)
IF M500 THEN
    (* 3. PUSH FIFO - DOC D1000/D2000/D4010 VAO *)
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

    (* 4. POP + REBASE *)
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

    (* 5. STATE: BAY(No le M0) -> HA(No M11) -> PHUN -> TAT M -> NHAC(No M10) -> TAT M *)
    CASE iState OF
        0:
            bValve := FALSE;
            rTargX := 0.0; rTargY := 0.0; rTargZ := rZTravel;
            rTmove := 0.0;
            rTdwell := 0.0;
            IF bActive THEN
                iState := 10;
            END_IF;
        10:
            bPosTimeout := FALSE;
            CASE iCorner OF
                1: rDx0 := 0.0 - rHalfSq; rDy0 := 0.0 - rHalfSq;
                2: rDx0 := rHalfSq;       rDy0 := 0.0 - rHalfSq;
                3: rDx0 := rHalfSq;       rDy0 := rHalfSq;
                4: rDx0 := 0.0 - rHalfSq; rDy0 := rHalfSq;
            END_CASE;

        COS_E(TRUE, rPartAng, rCosVal);
        SIN_E(TRUE, rPartAng, rSinVal);
        rDxRot := (rDx0 * rCosVal) - (rDy0 * rSinVal);
        rDyRot := (rDx0 * rSinVal) + (rDy0 * rCosVal);
        rTargX := rPartX0 + (rEncDist - rPartE0) + (rBeltF * rLeadT) + rDxRot;
        rTargY := rPartY0 + rDyRot;
        rTargZ := rZTravel;
        rSpd := rFly;
        wNo := (iCorner - 1) * 3 + 1;
        bFired := FALSE; bRunning := FALSE;
        rTmove := 0.0;
        iState := 20;
    20:
        bValve := FALSE;
        rTargX := rPartX0 + (rEncDist - rPartE0) + (rBeltF * rLeadT) + rDxRot;
        rTargZ := rZTravel;
        rTmove := rTmove + rDt;
        IF NOT bFired THEN
            IF X0 AND NOT X8 AND NOT X9 AND NOT XA THEN
                (* NHIP 1: tinh + ghi toa do/van toc xuong QD75 - chua RUN *)
                wAddrX := 2006 + (wNo - 1) * 10;
                wAddrY := 8006 + (wNo - 1) * 10;
                wAddrZ := 14006 + (wNo - 1) * 10;
                wSpdAddrX := 2004 + (wNo - 1) * 10;
                wSpdAddrY := 8004 + (wNo - 1) * 10;
                wSpdAddrZ := 14004 + (wNo - 1) * 10;
                dTargX_01um := REAL_TO_DINT(rTargX * 10000.0);
                dTargY_01um := REAL_TO_DINT(rTargY * 10000.0);
                dTargZ_01um := REAL_TO_DINT(rTargZ * 10000.0);
                dSpdStg := REAL_TO_DINT(rSpd);
                DTO(TRUE, dTargX_01um, H0, wAddrX, K2);
                DTO(TRUE, dTargY_01um, H0, wAddrY, K2);
                DTO(TRUE, dTargZ_01um, H0, wAddrZ, K2);
                DTO(TRUE, dSpdStg, H0, wSpdAddrX, K2);
                DTO(TRUE, dSpdStg, H0, wSpdAddrY, K2);
                DTO(TRUE, dSpdStg, H0, wSpdAddrZ, K2);
                TO(TRUE, wNo, H0, K1500, K1);
                bFired := TRUE;
                rLastX := rTargX; rLastY := rTargY; rLastZ := rTargZ;
            END_IF;
        END_IF;
        IF bFired AND NOT bStartReq AND NOT bRunning THEN
            IF X0 AND NOT XC AND NOT XD AND NOT XE AND NOT X4 THEN
                (* NHIP 2: du dieu kien moi cho xung Y10 RUN *)
                bStartReq := TRUE;
            END_IF;
        END_IF;
        IF bRunning AND X14 THEN
            rTargX := rPartX0 + (rEncDist - rPartE0) + (rBeltF * rLeadT) + rDxRot;
            rTargZ := rZGlue;
            rSpd := rDown;
            wNo := (iCorner - 1) * 3 + 2;
            bFired := FALSE; bRunning := FALSE;
            rTmove := 0.0;
            iState := 30;
        ELSIF rTmove >= rTimeoutS THEN
            bPosTimeout := TRUE;
            bStartReq := FALSE;
        END_IF;
    30:
        bValve := FALSE;
        rTargX := rPartX0 + (rEncDist - rPartE0) + (rBeltF * rLeadT) + rDxRot;
        rTargZ := rZGlue;
        rTmove := rTmove + rDt;
        IF NOT bFired THEN
            IF X0 AND NOT X8 AND NOT X9 AND NOT XA THEN
                (* NHIP 1: tinh + ghi toa do/van toc xuong QD75 - chua RUN *)
                wAddrX := 2006 + (wNo - 1) * 10;
                wAddrY := 8006 + (wNo - 1) * 10;
                wAddrZ := 14006 + (wNo - 1) * 10;
                wSpdAddrX := 2004 + (wNo - 1) * 10;
                wSpdAddrY := 8004 + (wNo - 1) * 10;
                wSpdAddrZ := 14004 + (wNo - 1) * 10;
                dTargX_01um := REAL_TO_DINT(rTargX * 10000.0);
                dTargY_01um := REAL_TO_DINT(rTargY * 10000.0);
                dTargZ_01um := REAL_TO_DINT(rTargZ * 10000.0);
                dSpdStg := REAL_TO_DINT(rSpd);
                DTO(TRUE, dTargX_01um, H0, wAddrX, K2);
                DTO(TRUE, dTargY_01um, H0, wAddrY, K2);
                DTO(TRUE, dTargZ_01um, H0, wAddrZ, K2);
                DTO(TRUE, dSpdStg, H0, wSpdAddrX, K2);
                DTO(TRUE, dSpdStg, H0, wSpdAddrY, K2);
                DTO(TRUE, dSpdStg, H0, wSpdAddrZ, K2);
                TO(TRUE, wNo, H0, K1500, K1);
                bFired := TRUE;
                rLastX := rTargX; rLastY := rTargY; rLastZ := rTargZ;
            END_IF;
        END_IF;
        IF bFired AND NOT bStartReq AND NOT bRunning THEN
            IF X0 AND NOT XC AND NOT XD AND NOT XE AND NOT X4 THEN
                (* NHIP 2: du dieu kien moi cho xung Y10 RUN *)
                bStartReq := TRUE;
            END_IF;
        END_IF;
        IF X4 AND (wMcode = 11) THEN
            bValve := TRUE;
            rTdwell := 0.0;
            iState := 40;
        ELSIF rTmove >= rTimeoutS THEN
            bPosTimeout := TRUE;
            bValve := FALSE;
            bStartReq := FALSE;
        END_IF;
    40:
        rTargX := rPartX0 + (rEncDist - rPartE0) + (rBeltF * rLeadT) + rDxRot;
        rTargZ := rZGlue;
        rTdwell := rTdwell + rDt;
        IF rTdwell >= rDwellS THEN
            bValve := FALSE;
            bMOffReq := TRUE;
            rTmove := 0.0;
            iState := 45;
        END_IF;
    45:
        rTmove := rTmove + rDt;
        IF NOT X4 THEN
            rTargX := rPartX0 + (rEncDist - rPartE0) + (rBeltF * rLeadT) + rDxRot;
            rTargZ := rZTravel;
            rSpd := rUp;
            wNo := (iCorner - 1) * 3 + 3;
            bFired := FALSE; bRunning := FALSE;
            rTmove := 0.0;
            iState := 50;
        ELSIF rTmove >= rTimeoutS THEN
            bPosTimeout := TRUE;
            bStartReq := FALSE;
        END_IF;
    50:
        bValve := FALSE;
        rTargX := rPartX0 + (rEncDist - rPartE0) + (rBeltF * rLeadT) + rDxRot;
        rTargZ := rZTravel;
        rTmove := rTmove + rDt;
        IF NOT bFired THEN
            IF X0 AND NOT X8 AND NOT X9 AND NOT XA THEN
                (* NHIP 1: tinh + ghi toa do/van toc xuong QD75 - chua RUN *)
                wAddrX := 2006 + (wNo - 1) * 10;
                wAddrY := 8006 + (wNo - 1) * 10;
                wAddrZ := 14006 + (wNo - 1) * 10;
                wSpdAddrX := 2004 + (wNo - 1) * 10;
                wSpdAddrY := 8004 + (wNo - 1) * 10;
                wSpdAddrZ := 14004 + (wNo - 1) * 10;
                dTargX_01um := REAL_TO_DINT(rTargX * 10000.0);
                dTargY_01um := REAL_TO_DINT(rTargY * 10000.0);
                dTargZ_01um := REAL_TO_DINT(rTargZ * 10000.0);
                dSpdStg := REAL_TO_DINT(rSpd);
                DTO(TRUE, dTargX_01um, H0, wAddrX, K2);
                DTO(TRUE, dTargY_01um, H0, wAddrY, K2);
                DTO(TRUE, dTargZ_01um, H0, wAddrZ, K2);
                DTO(TRUE, dSpdStg, H0, wSpdAddrX, K2);
                DTO(TRUE, dSpdStg, H0, wSpdAddrY, K2);
                DTO(TRUE, dSpdStg, H0, wSpdAddrZ, K2);
                TO(TRUE, wNo, H0, K1500, K1);
                bFired := TRUE;
                rLastX := rTargX; rLastY := rTargY; rLastZ := rTargZ;
            END_IF;
        END_IF;
        IF bFired AND NOT bStartReq AND NOT bRunning THEN
            IF X0 AND NOT XC AND NOT XD AND NOT XE AND NOT X4 THEN
                (* NHIP 2: du dieu kien moi cho xung Y10 RUN *)
                bStartReq := TRUE;
            END_IF;
        END_IF;
        IF X4 AND (wMcode = 10) THEN
            bMOffReq := TRUE;
            rTmove := 0.0;
            iState := 55;
        ELSIF rTmove >= rTimeoutS THEN
            bPosTimeout := TRUE;
            bStartReq := FALSE;
        END_IF;
    55:
        rTmove := rTmove + rDt;
        IF NOT X4 THEN
            IF iCorner < 4 THEN
                iCorner := iCorner + 1;
                iState := 10;
            ELSE
                bActive := FALSE;
                iState := 0;
            END_IF;
        ELSIF rTmove >= rTimeoutS THEN
            bPosTimeout := TRUE;
            bStartReq := FALSE;
        END_IF;
    ELSE
        iState := 0;
END_CASE;
END_IF;
(* 6. KEP BIEN mm *)
IF rTargX < rXMin THEN rTargX := rXMin; END_IF;
IF rTargX > rXMax THEN rTargX := rXMax; END_IF;
IF rTargY < rYMin THEN rTargY := rYMin; END_IF;
IF rTargY > rYMax THEN rTargY := rYMax; END_IF;
IF rTargZ < 0.0 THEN rTargZ := 0.0; END_IF;
IF rTargZ > 50.0 THEN rTargZ := 50.0; END_IF;

(* 7. RA TAG 32-bit - := LA MOVE/DMOV *)
dTargX_01um := REAL_TO_DINT(rTargX * 10000.0);
dTargY_01um := REAL_TO_DINT(rTargY * 10000.0);
dTargZ_01um := REAL_TO_DINT(rTargZ * 10000.0);
wMotionType := 1;
dStartX_01um := REAL_TO_DINT(rLastX * 10000.0);
dStartY_01um := REAL_TO_DINT(rLastY * 10000.0);
dStartZ_01um := REAL_TO_DINT(rLastZ * 10000.0);

(* 7b. RA D CHO VC/WATCH - DMOV 32-bit RA CAP D (D1010 = D1010+D1011) *)
DMOV(TRUE, dTargX_01um, D1010);
DMOV(TRUE, dTargY_01um, D2010);
DMOV(TRUE, dTargZ_01um, D3010);
DMOV(TRUE, dStartX_01um, D1020);
DMOV(TRUE, dStartY_01um, D2020);
DMOV(TRUE, dStartZ_01um, D3020);
DMOV(TRUE, dSpdStg, D4020);
D4030 := wMotionType;
M2000 := bValve;
M3000 := bQFull;
M3001 := bPosTimeout;

(* 8. TAT M (Cd.7 U0\G1504) - QD75 tu clear G1504=0 sau khi X4 OFF, KHONG ghi K0 de *)
IF bMOffReq THEN
    wTmp := 1;
    TO(TRUE, wTmp, H0, K1504, K1);
    IF NOT X4 THEN
        bMOffReq := FALSE;
    END_IF;
END_IF;
Y10 := bStartReq AND X0 AND NOT X10;
IF bStartReq AND X0 AND X10 THEN
    bStartReq := FALSE;
    bRunning := TRUE;
END_IF;

(* == BANG TAG LOCAL LABEL (paste tu o Class dong 1, Ctrl+V) == *)
(* VAR bInit Bit (Co khoi tao) *)
(* VAR bPrevTrig Bit (Nho xung M1000) *)
(* VAR bPrevEn Bit (Nho canh len M500) *)
(* VAR rEncDist FLOAT (Single Precision) (E mm) *)
(* VAR rBelt FLOAT (Single Precision) (D4000) *)
(* VAR rBeltF FLOAT (Single Precision) *)
(* VAR rAlpha FLOAT 1.0 | rLeadT FLOAT 0.8 | rDt FLOAT 0.01 *)
(* VAR rHalfSq 20 | rMoveS 1.0 | rDwellS 0.6 *)
(* VAR rXMin 0 rXMax 170 rYMin 0 rYMax 170 rZTravel 10 rZGlue 40 *)
(* VAR qPX/qPY/qPAng/qPE FLOAT(0..15) (FIFO 16) *)
(* VAR iHead/iTail/iCnt Word[Signed] *)
(* VAR bActive Bit | rPartX0/rPartY0/rPartAng/rPartE0 FLOAT *)
(* VAR iState/iCorner Word[Signed] | rDx0/rDy0/rDxRot/rDyRot/rCosVal/rSinVal FLOAT *)
(* VAR rTmove/rTdwell/rTargX/rTargY/rTargZ FLOAT *)
(* VAR dTargX_01um Double Word D1010 | dTargY_01um D2010 | dTargZ_01um D3010 *)
(* VAR bValve Bit M2000 | bQFull Bit M3000 *)
(* VAR rTimeoutS 8.0 | bPosTimeout Bit M3001 *)
(* VAR wNo/wAddrX/wAddrY/wAddrZ/wMcode/wTmp Word[Signed] *)
(* VAR bStartReq/bFired/bRunning/bMOffReq Bit *)
(* VAR rMaster/rSpdLim/rFly/rDown/rUp/rSpd FLOAT *)
(* VAR dSpdStg Double Word D4020 | wSpdAddrX/wSpdAddrY/wSpdAddrZ Word *)
(* VAR rLastX/rLastY/rLastZ FLOAT *)
(* VAR dStartX_01um D1020 | dStartY_01um D2020 | dStartZ_01um D3020 (Double Word) *)
(* VAR wMotionType Word D4030 (=1 thang) *)
(* M500/M1000/Y0/X0/Y10/X10/X14/X4/XC/XD/XE/X8/X9/XA + D dung truc tiep, khong khai *)
