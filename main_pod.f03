      program main_pod


! ----------------------------------------------------------------------
! Program:	main_pod.f03
! ----------------------------------------------------------------------
! Purpose:
!  Precise Orbit Determination (POD) of GNSS satellites 
! ----------------------------------------------------------------------
! Author :	Dr. Thomas Papanikolaou
!			Geoscience Australia, CRC-SI
! Created:	13 September 2017
! ----------------------------------------------------------------------
! POD version major modifications highlights: 
! Last modified  
! - Dr. Thomas Papanikolaou, 3 May 2018
! 	Preliminary version of GNSS dynamic orbit determination	
! - Dr. Thomas Papanikolaou, 25 June 2018
! 	Version with minor revisions
! - Dr. Thomas Papanikolaou, 30 November 2018
! 	Precise Orbit Determination (POD) version: Estimation of empirical forces parameters (bias, cycle-per-rev) that lead to mm-cm level orbital accuracy w.r.t. IGS precise orbits
! - Dr. Thomas Papanikolaou, 30 January 2019
! 	POD version upgrade: Ocean tides effect revision that has significant impact on longer orbit arcs e.g. 3 days 
! - Dr. Thomas Papanikolaou, 29 March 2019
! 	POD version upgrade to a multi-GNSS multi-satellite POD version 
! ----------------------------------------------------------------------


      USE mdl_precision
      USE mdl_num
      USE mdl_param
      USE m_pod_gnss
      !USE m_orbitmain
      USE m_writeorbit_multi
      !USE m_orbdet
      !USE m_orbext
      USE m_writearray
      USE m_writearray2
      USE m_writeorbit
	  !USE mdl_planets
	  !USE mdl_tides
	  !USE mdl_eop
	  !USE m_sp3_PRN
	  USE m_write_orb2sp3
      IMPLICIT NONE

	  
! ----------------------------------------------------------------------
      REAL (KIND = prec_d) :: CPU_t0, CPU_t1
      CHARACTER (LEN=100) :: EQMfname, VEQfname, PODfname, ORBMODfname				
      CHARACTER (LEN=100) :: EQMfname_initial, VEQfname_initial				
      INTEGER (KIND = prec_int2) :: ios_line, ios_key, ios_data
      REAL (KIND = prec_d), DIMENSION(:,:), ALLOCATABLE :: orb_icrf, orb_itrf  
      REAL (KIND = prec_d), DIMENSION(:,:), ALLOCATABLE :: veqSmatrix, veqPmatrix
      REAL (KIND = prec_d), DIMENSION(:,:), ALLOCATABLE :: Vres  
      REAL (KIND = prec_d), DIMENSION(3) :: Vrms 	    
	  !REAL (KIND = prec_d), DIMENSION(5,6) :: stat_XYZ_extC, stat_RTN_extC, stat_Kepler_extC, stat_XYZ_extT
! ----------------------------------------------------------------------
      CHARACTER (LEN=2) :: GNSS_id
	  INTEGER (KIND = prec_int2) :: ORB_mode
! ----------------------------------------------------------------------
	  INTEGER (KIND = prec_int8) :: Nsat, isat
	  INTEGER (KIND = prec_int8) :: iepoch, iparam
	  INTEGER (KIND = prec_int8) :: i
	  INTEGER (KIND = prec_int8) :: sz1, sz2, Nepochs, N2_orb, N2_veqSmatrix, N2_veqPmatrix, N2sum  
      REAL (KIND = prec_d), DIMENSION(:,:,:), ALLOCATABLE :: orbits_partials_icrf  
      REAL (KIND = prec_d), DIMENSION(:,:,:), ALLOCATABLE :: orbits_partials_itrf  
	  CHARACTER (LEN=3), ALLOCATABLE :: PRNmatrix(:)
      INTEGER (KIND = prec_int2) :: AllocateStatus, DeAllocateStatus  
	  CHARACTER (LEN=3) :: PRN_isat
	  INTEGER :: ios
      CHARACTER (LEN=100) :: orbits_fname				
      CHARACTER (LEN=100) :: fname_write				
      CHARACTER (LEN=100) :: filename				
! ----------------------------------------------------------------------
      CHARACTER (LEN=300) :: fname_sp3, ORBpseudobs_fname, ORBEXT_fname				
	  INTEGER :: year, month, day
	  INTEGER :: Iyear, Imonth, Iday
      REAL (KIND = prec_d) :: Sec_00 	    
! ----------------------------------------------------------------------
      CHARACTER (LEN=50) :: fname_id				
      CHARACTER (LEN=100) :: param_id				
      CHARACTER (LEN=500) :: param_value				
      REAL (KIND = prec_d) :: Zo(6) 
! ----------------------------------------------------------------------
      CHARACTER (LEN=100) :: ORB2sp3_fname				
      INTEGER (KIND = prec_int2) :: sat_vel	  	  
! ----------------------------------------------------------------------
      REAL (KIND = prec_d), DIMENSION(:,:), ALLOCATABLE :: orbit_resR  
      REAL (KIND = prec_d), DIMENSION(:,:), ALLOCATABLE :: orbit_resT  
      REAL (KIND = prec_d), DIMENSION(:,:), ALLOCATABLE :: orbit_resN  
! ----------------------------------------------------------------------
      REAL (KIND = prec_d) :: mjd
      INTEGER (KIND = prec_int8) :: GPS_week, GPSweek_mod1024
      REAL (KIND = prec_d) :: GPS_wsec, GPS_day
! ----------------------------------------------------------------------
	  INTEGER (KIND = prec_int8) :: Ncommon  
      REAL (KIND = prec_d), DIMENSION(:,:), ALLOCATABLE :: dorb_icrf, dorb_itrf 
      REAL (KIND = prec_d), DIMENSION(:,:), ALLOCATABLE :: dorb_RTN, dorb_Kepler
! ----------------------------------------------------------------------
      !INTEGER (KIND = prec_int2) :: POD_MODE_glb	  	  
      !REAL (KIND = prec_d) :: ORBPRED_ARC_glb
      REAL (KIND = prec_d) :: orbarc_sum
      REAL (KIND = prec_d) :: orb_est_arc
      INTEGER (KIND = prec_int2) :: IC_MODE	  	  
      CHARACTER (LEN=500) :: IC_REF				
      REAL (KIND = prec_d), DIMENSION(:,:,:), ALLOCATABLE :: orbdiff2

	  
	  
	  
! CPU Time
CALL cpu_time (CPU_t0)



! ----------------------------------------------------------------------
! POD major configuration file
! ----------------------------------------------------------------------
PODfname = 'POD.in'
! ----------------------------------------------------------------------




! ----------------------------------------------------------------------  ! 999999999999999999999999999
! ----------------------------------------------------------------------
! Temporary:: manual configuration of 4 global parameters
! ----------------------------------------------------------------------

! ----------------------------------------------------------------------
! Write option for Satellite Velocity vector in computed orbit to output sp3 format 
! ----------------------------------------------------------------------
! 0. sat_vel = 0 :: Do not write Velocity vector to sp3 orbit
! 1. sat_vel > 0 :: Write Velocity vector to sp3 orbit
sat_vel = 1
! ----------------------------------------------------------------------


! ----------------------------------------------------------------------
! "GPS satellite Block" and "Beidou Orbit Type"
! ----------------------------------------------------------------------
! GPS case: Satellite Block ID:	1=I, 2=II, 3=IIA, IIR=(4, 5), IIF=6
SATblock_glb = 2
! ----------------------------------------------------------------------
! Beidou case:
! 1. BDSorbtype = 'IGSO'
! 2. BDSorbtype = 'MEO'
BDSorbtype_glb = 'MEO'
! ----------------------------------------------------------------------
! Empirical Forces reference frame:
! 1. Orbital Frame
! 2. Body-fixed frame
Frame_EmpiricalForces_glb = 1
! ----------------------------------------------------------------------
!print *,"Frame_EmpiricalForces_glb ", Frame_EmpiricalForces_glb
!print *,"SATblock_glb              ", SATblock_glb
!print *,"BDSorbtype_glb            ", BDSorbtype_glb
!print *,"              "

! ----------------------------------------------------------------------
! Temporary :: End of input POD configuration
! ----------------------------------------------------------------------
! ----------------------------------------------------------------------  ! 999999999999999999999999999




! ----------------------------------------------------------------------
! Form (rewrite) the two orbit integration configuration files for 
! Equation of Motion and Variational Equations: EQM.in and VEQ.in 
! ----------------------------------------------------------------------


! ----------------------------------------------------------------------
! POD Tool mode:
! ----------------------------------------------------------------------
! 1. Orbit Determination (pseudo-observations; orbit fitting)
! 2. Orbit Determination and Prediction
! 3. Orbit Integration (Equation of Motion only)
! 4. Orbit Integration and Partials (Equation of Motion and Variational Equations)
! ----------------------------------------------------------------------
!POD_MODE_glb = 2 
param_id = 'POD_mode'
CALL readparam (PODfname, param_id, param_value)
READ ( param_value, FMT = * , IOSTAT=ios_key ) POD_MODE_glb 
!print *, "POD_MODE_glb", POD_MODE_glb

If      (POD_MODE_glb == 1) then
Print *,"POD Tool mode: 1 :: Orbit Determination"
Else IF (POD_MODE_glb == 2) then 
Print *,"POD Tool mode: 2 :: Orbit Determination and Prediction"
Else IF (POD_MODE_glb == 3) then 
Print *,"POD Tool mode: 3 :: Orbit Integration"
Else IF (POD_MODE_glb == 4) then 
Print *,"POD Tool mode: 2 :: Orbit Integration and Partials"
End IF
Print *," "
! ----------------------------------------------------------------------

! ----------------------------------------------------------------------
! Initial Conditions input mode
! ----------------------------------------------------------------------
! 1. Input a-priori orbit in sp3 format (applied as pseudo-observations)
! 2. Input file with Initial Conditions (State Vector and Parameters at initial epoch per satellite) 
! ----------------------------------------------------------------------
!IC_MODE = 1
param_id = 'IC_input'
CALL readparam (PODfname, param_id, param_value)
READ ( param_value, FMT = * , IOSTAT=ios_key ) IC_MODE 

! Initial Conditions reference frame
!IC_REF  = 'ITRF'
param_id = 'IC_refsys'
CALL readparam (PODfname, param_id, param_value)
READ ( param_value, FMT = * , IOSTAT=ios_key ) IC_REF 
! ----------------------------------------------------------------------

! ----------------------------------------------------------------------
! Configuration files of Orbit modelling (2 Basic initial files):
! ----------------------------------------------------------------------
!EQMfname_initial = 'EQM.in'
!VEQfname_initial = 'VEQ.in'

! Equation of Motion
param_id = 'EQM_filename'
CALL readparam (PODfname, param_id, param_value)
READ ( param_value, FMT = * , IOSTAT=ios_key ) EQMfname_initial 
!print *, "EQMfname_initial", EQMfname_initial

! Variational Equations
param_id = 'VEQ_filename'
CALL readparam (PODfname, param_id, param_value)
READ ( param_value, FMT = * , IOSTAT=ios_key ) VEQfname_initial 
!print *, "VEQfname_initial", VEQfname_initial
! ----------------------------------------------------------------------

! ----------------------------------------------------------------------
! POD_MODE Cases: 1 or 2  
! ----------------------------------------------------------------------
! A-priori orbit sp3 as pseudo-observations :: sp3 file name
! ----------------------------------------------------------------------
param_id = 'pseudobs_filename'
CALL readparam (PODfname, param_id, param_value)
READ ( param_value, FMT = * , IOSTAT=ios_key ) ORBpseudobs_fname 
!print *, "ORBpseudobs_fname", ORBpseudobs_fname
! ----------------------------------------------------------------------

! ----------------------------------------------------------------------
! POD_MODE Cases: ALL  (IF orbit_external_opt .NE. 0 see EQM.in configuration file)
! ----------------------------------------------------------------------
! External Orbit Comparison :: sp3 file name
! ----------------------------------------------------------------------
!ORBEXT_fname = ORBpseudobs_fname
param_id = 'orbit_filename'
CALL readparam (PODfname, param_id, param_value)
READ ( param_value, FMT = * , IOSTAT=ios_key ) ORBEXT_fname 
!print *, "ORBEXT_fname", ORBEXT_fname
! ----------------------------------------------------------------------

! ----------------------------------------------------------------------
! Orbit Estimation arc length
! ----------------------------------------------------------------------
param_id = 'Orbit_arc_length'
CALL readparam (PODfname, param_id, param_value)
READ ( param_value, FMT = * , IOSTAT=ios_key ) orb_est_arc 
! Convert Hours to Seconds
orb_est_arc = orb_est_arc * 3600.D0
!print *, "orb_est_arc", orb_est_arc
! ----------------------------------------------------------------------

! ----------------------------------------------------------------------
! POD_MODE Cases: 2  
! ----------------------------------------------------------------------
! Orbit Prediction arc length (Seconds)
! ----------------------------------------------------------------------
param_id = 'orbit_prediction_arc'
CALL readparam (PODfname, param_id, param_value)
READ ( param_value, FMT = * , IOSTAT=ios_key ) ORBPRED_ARC_glb 
! Convert Hours to Seconds
ORBPRED_ARC_glb = ORBPRED_ARC_glb * 3600.D0
!print *, "ORBPRED_ARC_glb", ORBPRED_ARC_glb
! ----------------------------------------------------------------------


! ----------------------------------------------------------------------
! Copy Initial Configuration files 
! ----------------------------------------------------------------------
fname_id = '0'
CALL write_prmfile2 (EQMfname_initial, fname_id, EQMfname)
CALL write_prmfile2 (VEQfname_initial, fname_id, VEQfname)
! ----------------------------------------------------------------------
!print *,"EQMfname ", EQMfname
!print *,"VEQfname ", VEQfname
!print *,"              "


! ----------------------------------------------------------------------
! Rewrite Configuration files :: Set POD_MODE
! ----------------------------------------------------------------------
fname_id = '1'
IF (POD_MODE_glb == 1 .OR. POD_MODE_glb == 2) THEN
param_id = 'VEQ_integration'
param_value = '1'
Call write_prmfile (EQMfname, fname_id, param_id, param_value)
Call write_prmfile (VEQfname, fname_id, param_id, param_value)

param_id = 'Estimator_procedure'
param_value = '1'
Call write_prmfile (EQMfname, fname_id, param_id, param_value)
Call write_prmfile (VEQfname, fname_id, param_id, param_value)

ELSE IF (POD_MODE_glb == 3) THEN
param_id = 'VEQ_integration'
param_value = '0'
Call write_prmfile (EQMfname, fname_id, param_id, param_value)
Call write_prmfile (VEQfname, fname_id, param_id, param_value)

param_id = 'Estimator_procedure'
param_value = '0'
Call write_prmfile (EQMfname, fname_id, param_id, param_value)
Call write_prmfile (VEQfname, fname_id, param_id, param_value)

ELSE IF (POD_MODE_glb == 4) THEN
param_id = 'VEQ_integration'
param_value = '1'
Call write_prmfile (EQMfname, fname_id, param_id, param_value)
Call write_prmfile (VEQfname, fname_id, param_id, param_value)

param_id = 'Estimator_procedure'
param_value = '0'
Call write_prmfile (EQMfname, fname_id, param_id, param_value)
Call write_prmfile (VEQfname, fname_id, param_id, param_value)

END IF
! ----------------------------------------------------------------------

! ----------------------------------------------------------------------
! Rewrite Configuration files :: Set orbit estimation arc length
! ----------------------------------------------------------------------
fname_id = '1'
param_id = 'Orbit_arc_length'
write (param_value, *) orb_est_arc
Call write_prmfile (EQMfname, fname_id, param_id, param_value)
Call write_prmfile (VEQfname, fname_id, param_id, param_value)
! ----------------------------------------------------------------------

! ----------------------------------------------------------------------
! Rewrite Configuration files :: Set a-priori orbit (pseudo-observations; orbit comparison)
! ----------------------------------------------------------------------
fname_id = '1'
param_id = 'pseudobs_filename'
param_value = ORBpseudobs_fname
Call write_prmfile (EQMfname, fname_id, param_id, param_value)
Call write_prmfile (VEQfname, fname_id, param_id, param_value)

param_id = 'orbit_filename'
param_value = ORBEXT_fname
Call write_prmfile (EQMfname, fname_id, param_id, param_value)
Call write_prmfile (VEQfname, fname_id, param_id, param_value)
! ----------------------------------------------------------------------



! ----------------------------------------------------------------------
! ----------------------------------------------------------------------
! POD of the GNSS satellites constellations
! ----------------------------------------------------------------------
CALL pod_gnss (EQMfname, VEQfname, PRNmatrix, orbits_partials_icrf, orbits_partials_itrf, &
               orbit_resR, orbit_resT, orbit_resN, orbdiff2)
! ----------------------------------------------------------------------
! ----------------------------------------------------------------------



! ----------------------------------------------------------------------
! Write satellite orbits and partial derivatives to one .orb output file (internal format)
! ----------------------------------------------------------------------
orbits_fname = 'orbits_partials_icrf.orb'
CALL writeorbit_multi (orbits_partials_icrf, PRNmatrix, orbits_fname)
! ----------------------------------------------------------------------

! ----------------------------------------------------------------------
! Write satellite orbits to sp3 format
! ----------------------------------------------------------------------
!mjd = orbits_partials_icrf(1,1,1)
mjd = orbits_partials_itrf(2,1,1)
CALL time_GPSweek  (mjd, GPS_week, GPS_wsec, GPSweek_mod1024)
!CALL time_GPSweek2 (mjd, GPS_week, GPS_wsec, GPSweek_mod1024, GPS_day)
GPS_day = ( GPS_wsec/86400.0D0 )  
write (ORB2sp3_fname, FMT='(A3,I4,I1,A4)') 'gag', (GPS_week), INT(GPS_day) ,'.sp3'

! ICRF
!CALL write_orb2sp3 (orbits_partials_icrf, PRNmatrix, ORB2sp3_fname, sat_vel)
! ITRF
CALL write_orb2sp3 (orbits_partials_itrf, PRNmatrix, ORB2sp3_fname, sat_vel)
! ----------------------------------------------------------------------

! ----------------------------------------------------------------------
! Write Orbit residuals
! ----------------------------------------------------------------------
filename = "orbit_residuals_R.out"
Call writearray (orbit_resR, filename)
filename = "orbit_residuals_T.out"
Call writearray (orbit_resT, filename)
filename = "orbit_residuals_N.out"
Call writearray (orbit_resN, filename)
! ----------------------------------------------------------------------


filename = "orbdiff2.out"
Call writearray2 (orbdiff2, filename)



CALL cpu_time (CPU_t1)
PRINT *,"CPU Time (sec)", CPU_t1-CPU_t0


End Program
