!##############################################################################
!##############################################################################
      program MetSonde

      use MetReader

      implicit none

      integer             :: nargs
      integer             :: status
      character (len=100) :: arg

      real(kind=4)        :: inlon,inlat
      integer             :: inyear,inmonth,inday
      real(kind=8)        :: inhour

      character(len=100)  :: WINDROOT = '/data/WindFiles'
      integer             :: FC_freq = 12
      integer             :: nxmax,nymax,nzmax !,nsize
      real(kind=4),dimension(:)    ,allocatable :: lon_grid
      real(kind=4),dimension(:)    ,allocatable :: lat_grid
      real(kind=4),dimension(:)    ,allocatable :: z_cc
      logical             :: IsPeriodic

      integer :: iprojflag
      real(kind=8) :: lambda0,phi0,phi1,phi2,k0,radius_earth
      logical :: IsLatLon

      integer :: BaseYear = 1900
      logical :: useLeap  = .true.

      INTERFACE
        subroutine GetWindFile_FC(inyear,inmonth,inday,inhour,infile1,FC_freq)
          integer,parameter   :: dp        = 8 ! double precision
          integer             :: inyear,inmonth,inday
          real(kind=dp)       :: inhour
          character(len=100)  :: infile1
          integer             :: FC_freq
        end subroutine
        subroutine GetMetProfile(inlon,inlat,inyear,inmonth,inday,inhour)
          integer,parameter   :: sp        = 4 ! single precision
          integer,parameter   :: dp        = 8 ! double precision
          real(kind=sp)       :: inlon
          real(kind=sp)       :: inlat
          integer             :: inyear,inmonth,inday
          real(kind=dp)       :: inhour
        end subroutine
      END INTERFACE


      ! Make sure user MetReader is using the same calendar
      MR_BaseYear = BaseYear
      MR_useLeap  = useLeap

!     TEST READ COMMAND LINE ARGUMENTS
      nargs = command_argument_count()
      if (nargs.lt.6) then
        write(6,*)"Enter lon lat YYYY MM DD HH [WIND_ROOT]"
        stop 1
      else
        call get_command_argument(1, arg, status)
        read(arg,*)inlon
        if(inlon.lt.-360.0)then
          write(6,*)"ERROR: Longitude must be gt -360"
          stop 1
        endif
        if(inlon.lt.0.0_4.or.inlon.gt.360.0_4)inlon=mod(inlon+360.0_4,360.0_4)
        call get_command_argument(2, arg, status)
        read(arg,*)inlat
        call get_command_argument(3, arg, status)
        read(arg,*)inyear
        call get_command_argument(4, arg, status)
        read(arg,*)inmonth
        call get_command_argument(5, arg, status)
        read(arg,*)inday
        call get_command_argument(6, arg, status)
        read(arg,*)inhour
        if(nargs.ge.7)then
          call get_command_argument(7, arg, status)
          WINDROOT = TRIM(arg)
        endif
      endif

      write(6,*)"Interpolating profile onto ",inlon,inlat

      write(6,*)"Set up winfile data structure"
      call GetWindFile_FC(inyear,inmonth,inday,inhour,WINDROOT,FC_freq)

      nxmax = 3 ! 
      nymax = 3 ! 
      nzmax = 2 ! This is not really used in this utility
      allocate(lon_grid(nxmax)); lon_grid(1:3) = (/inlon-0.5_4,inlon,inlon+0.5_4/)
      allocate(lat_grid(nymax)); lat_grid(1:3) = (/inlat-0.5_4,inlat,inlat+0.5_4/)
      allocate(z_cc(nzmax))    ; z_cc(1:2) = (/0.0_4, 10.0_4/)
      IsPeriodic = .false.

      IsLatLon = .true.
        ! These are all dummy values since the comp grid is lon/lat
      iprojflag = 1
      lambda0      = -105.0
      phi0         = 90.0
      phi1         = 90.0
      phi2         = 90.0
      k0           = 0.933
      radius_earth = 6371.229
      call MR_Set_CompProjection(IsLatLon,iprojflag,lambda0,phi0,phi1,phi2,&
                                 k0,radius_earth)

      write(6,*)"Setting up wind grids"
      call MR_Initialize_Met_Grids(nxmax,nymax,nzmax,&
                              lon_grid(1:nxmax), &
                              lat_grid(1:nymax), &
                              z_cc(1:nzmax)    , &
                              IsPeriodic)

      call GetMetProfile(inlon,inlat,inyear,inmonth,inday,inhour)

      !call WriteGnuplotScript(inlon,inlat,inyear,inmonth,inday,inhour)

      write(6,*)"Program ended normally."

      end program MetSonde

!##############################################################################
!
!     Subroutines
!
!##############################################################################

!##############################################################################
!##############################################################################

      subroutine GetWindFile_FC(inyear,inmonth,inday,inhour,infile1,FC_freq)

      use MetReader

      implicit none

      integer            :: inyear,inmonth,inday
      real(kind=8)       :: inhour
      character(len=100) :: infile1
      integer            :: FC_freq

      real(kind=8)       :: HS_hours_since_baseyear
      character(len=13)  :: HS_yyyymmddhhmm_since   ! function that calculates date
                                                      !  string given
                                                      !  hours since
                                                      !  MR_BaseYear
      integer            :: HS_YearOfEvent
      integer            :: HS_MonthOfEvent
      integer            :: HS_DayOfEvent
      real(kind=8)       :: HS_HourOfDay


      character(len=8)   :: date
      character(LEN=10)  :: time2         ! time argument used to get current
                                          !  date and time.
      character(len=5)   :: zone  !variables used by the date_and_time subroutine
      integer            :: values(8)     !return values from date_and_time
      integer            :: timezone      ! timezone of grid relative to UTC

      real(kind=8)      :: StartHour
      real(kind=8)      :: RunStartHour    ! Current UTC time, in hours since MR_BaseYear
      character(len=17) :: RunStartHour_ch
      real(kind=8)      :: Probe_StartHour
      real(kind=8)      :: FC_Package_StartHour

      real(kind=8) :: GFS_Avail_Delay = 10.0
      integer      :: GFS_Archive_Days = 14

      integer      :: RunStartYear
      integer      :: RunStartMonth
      integer      :: RunStartDay
      integer      :: RunStartHr

      integer      :: FC_Package_hour
      integer      :: FC_hour_int

      integer      :: iw,iwf,igrid,iwfiles
      real(kind=8)      :: Simtime_in_hours = 0.0
      character(len=47) :: string1,string2

      integer :: i
      integer :: FC_year,FC_mon,FC_day
      real(kind=8) :: FC_hour,FC_intvl

       ! Get the UTC time that the program is called
       !   This will be used to determine if gfs or NCEP winds are to be used
      call date_and_time(date,time2,zone,values)
      read(zone,'(i3)') timezone
        ! FIND TIME IN UTC
      StartHour = real(values(5)-timezone,kind=8) + &
                  real(values(6)/60.0,kind=8)
        ! find time in hours since BaseYear
      RunStartHour = HS_hours_since_baseyear(values(1),values(2),values(3),&
                                             StartHour,MR_BaseYear,MR_useLeap)
        ! get character string
      RunStartHour_ch = HS_yyyymmddhhmm_since(RunStartHour,MR_BaseYear,MR_useLeap)
      read(RunStartHour_ch,'(i4)') RunStartYear
      read(RunStartHour_ch,'(4x,i2)') RunStartMonth
      read(RunStartHour_ch,'(6x,i2)') RunStartDay
      read(RunStartHour_ch,'(8x,i2)') RunStartHr

      ! Now find the Forecast block that starts immediately before the
      ! called time
      FC_Package_hour = floor(inhour/FC_freq) * FC_freq
      FC_Package_StartHour = HS_hours_since_baseyear(inyear,inmonth,inday,&
                                                     real(FC_Package_hour,kind=8),&
                                                     MR_BaseYear,MR_useLeap)
      Probe_StartHour = HS_hours_since_baseyear(inyear,inmonth,inday,inhour,&
                                                MR_BaseYear,MR_useLeap)
      MR_Comp_StartHour = Probe_StartHour
      MR_Comp_Time_in_hours = Simtime_in_hours

      if(RunStartHour-FC_Package_StartHour.lt.GFS_Avail_Delay)then
        ! The closest forecast package to the probe time is too close to
        ! the current (real) time.  The GFS files are probably not yet
        ! available.  Decrement the forecast package.
        FC_Package_StartHour = FC_Package_StartHour - real(FC_freq,kind=8)
        FC_year = HS_YearOfEvent(FC_Package_StartHour,MR_BaseYear,MR_useLeap)
        FC_mon  = HS_MonthOfEvent(FC_Package_StartHour,MR_BaseYear,MR_useLeap)
        FC_day  = HS_DayOfEvent(FC_Package_StartHour,MR_BaseYear,MR_useLeap)
        FC_hour = HS_HourOfDay(FC_Package_StartHour,MR_BaseYear,MR_useLeap)
        FC_Package_hour = floor(FC_hour/FC_freq) * FC_freq
      else
        FC_year = inyear
        FC_mon  = inmonth
        FC_day  = inday
        FC_hour = inhour
      endif

      if(RunStartHour-Probe_StartHour.gt.(GFS_Archive_Days*24))then
        ! Run is older than 2 weeks, use NCEP winds
        iw  = 5
        iwf = 25
        igrid   = 0
        iwfiles = 1

        call MR_Allocate_FullMetFileList(iw,iwf,igrid,2,iwfiles)
                           !     Probe_StartHour,Simtime_in_hours)
        do i=1,MR_iwindfiles
          write(MR_windfiles(i),*)trim(ADJUSTL(infile1)), &
                               '/NCEP'
        enddo

      elseif(RunStartHour-Probe_StartHour.lt.-90)then
        ! Run is too far in the future
        write(6,*)"ERROR: run is too far in future"
        stop 1
      else
        ! Run is newer than 2 weeks, use GFS winds
        iw      = 4
        iwf     = 20
        igrid   = 0
        iwfiles = 34
        FC_intvl = 3.0

        call MR_Allocate_FullMetFileList(iw,iwf,igrid,2,iwfiles)
        do i=1,MR_iwindfiles
          FC_hour_int = nint((i-1)*FC_intvl)
          write(string1,'(a9,I4.4,I2.2,I2.2,I2.2,a1)')'/gfs/gfs.', &
                        FC_year,FC_mon,FC_day,FC_Package_hour,'/'
          write(string2,'(I4.4,I2.2,I2.2,I2.2,a2,I3.3,a3)') &
                         FC_year,FC_mon,FC_day,FC_Package_hour, &
                        '.f',FC_hour_int,'.nc'
          write(MR_windfiles(i),*)trim(ADJUSTL(infile1)), &
                               trim(ADJUSTL(string1)), &
                               trim(ADJUSTL(string2))
        enddo

      endif
        ! Check for existance and compatibility with simulation time requirements
      call MR_Read_Met_DimVars(FC_year)

      call MR_Set_Met_Times(Probe_StartHour, Simtime_in_hours)


      write(6,*)"Traj time: ",inyear,inmonth,inday,inhour
      write(6,*)"Now      : ",RunStartYear,RunStartMonth,RunStartDay,RunStartHr
      write(6,*)"FC  time : ",inyear,inmonth,inday,FC_Package_hour

      end subroutine GetWindFile_FC

!##############################################################################
!##############################################################################

      subroutine GetMetProfile(inlon,inlat,inyear,inmonth,inday,inhour)

      use MetReader

      implicit none

      real(kind=4)       :: inlon
      real(kind=4)       :: inlat
      integer            :: inyear,inmonth,inday
      real(kind=8)       :: inhour

      real(kind=8)       :: HS_hours_since_baseyear
      real(kind=8)       :: Probe_StartHour
      integer            :: ivar,i
      real(kind=4),dimension(:,:,:),allocatable :: AirTemp_meso_last_step_MetP_sp
      real(kind=4),dimension(:,:,:),allocatable :: AirTemp_meso_next_step_MetP_sp
      real(kind=4) :: tfrac,tc,xfrac,xc,yfrac,yc
      real(kind=4) :: a1,a2,a3,a4

      real(kind=4),dimension(:),allocatable :: GPHprof1,GPHprof2,GPHprof
      real(kind=4),dimension(:),allocatable :: tempprof1,tempprof2,tempprof
      real(kind=4) :: TropoH,TropoP,TropoT
      real(kind=4) :: lapse_1,lapse_2,lapse_3


      allocate(AirTemp_meso_last_step_MetP_sp(nx_submet,ny_submet,np_fullmet))
      allocate(AirTemp_meso_next_step_MetP_sp(nx_submet,ny_submet,np_fullmet))
      allocate(GPHprof(np_fullmet))
      allocate(GPHprof1(np_fullmet))
      allocate(GPHprof2(np_fullmet))
      allocate(tempprof(np_fullmet))
      allocate(tempprof1(np_fullmet))
      allocate(tempprof2(np_fullmet))

      write(6,*)" Inside GetMetProfile"

      ! First load the Met grids for Geopotential
      MR_iMetStep_Now = 1 ! This is initialized to 0
      call MR_Read_HGT_arrays(MR_iMetStep_Now)
      ivar = 5 ! Temperature
      call MR_Read_3d_MetP_Variable(ivar,MR_iMetStep_Now)
      AirTemp_meso_last_step_MetP_sp = MR_dum3d_MetP

      call MR_Read_3d_MetP_Variable(ivar,MR_iMetStep_Now+1)
      AirTemp_meso_next_step_MetP_sp = MR_dum3d_MetP

      
      ! Get the fractional time between forecast steps
      Probe_StartHour = HS_hours_since_baseyear(inyear,inmonth,inday,inhour,&
                                                MR_BaseYear,MR_useLeap)
      tfrac = real((Probe_StartHour-MR_MetStep_Hour_since_baseyear(1)) / &
               MR_MetStep_Interval(MR_iMetStep_Now),kind=4)
      tc    = 1.0_4-tfrac
      ! Get the fractional position in cell and corner weights
      xfrac=(inlon - x_submet_sp(1))/dx_met_const
      yfrac=(inlat - y_submet_sp(1))/dy_met_const
      xc = 1.0_4-xfrac
      yc = 1.0_4-yfrac
      a1=xc*yc
      a2=xfrac*yc
      a3=xfrac*yfrac
      a4=yfrac*xc
      GPHprof1  = a1*MR_geoH_metP_last(1,1,:) + &
                  a2*MR_geoH_metP_last(2,1,:) + &
                  a3*MR_geoH_metP_last(2,2,:) + &
                  a4*MR_geoH_metP_last(1,2,:)

      tempprof1 = a1*AirTemp_meso_last_step_MetP_sp(1,1,:) + &
                  a2*AirTemp_meso_last_step_MetP_sp(2,1,:) + &
                  a3*AirTemp_meso_last_step_MetP_sp(2,2,:) + &
                  a4*AirTemp_meso_last_step_MetP_sp(1,2,:)
      GPHprof2  = a1*MR_geoH_metP_next(1,1,:) + &
                  a2*MR_geoH_metP_next(2,1,:) + &
                  a3*MR_geoH_metP_next(2,2,:) + &
                  a4*MR_geoH_metP_next(1,2,:)

      tempprof2 = a1*AirTemp_meso_next_step_MetP_sp(1,1,:) + &
                  a2*AirTemp_meso_next_step_MetP_sp(2,1,:) + &
                  a3*AirTemp_meso_next_step_MetP_sp(2,2,:) + &
                  a4*AirTemp_meso_next_step_MetP_sp(1,2,:)

      write(6,*)x_submet_sp
      write(6,*)y_submet_sp
      write(6,*)"t frac comp",tfrac,tc
      write(6,*)"x frac comp",xfrac,xc
      write(6,*)"y frac comp",yfrac,yc
      write(6,*)a1,a2,a3,a4

      open(unit=20,file='GFS_prof.dat')
      do i = 1,np_fullmet
        GPHprof(i) = tc*GPHprof1(i) + tfrac*GPHprof2(i)
        tempprof(i) = tc*tempprof1(i) + tfrac*tempprof2(i)
        write(20,*)GPHprof(i),p_fullmet_sp(i),tempprof(i)-273.0
      enddo
      close(20)

      ! Get Height of tropopause by calculating lapse rate
      do i = 2,np_fullmet-2
        lapse_1 = (tempprof(i-1)-tempprof(i  ))/(GPHprof(i  )-GPHprof(i-1))
        lapse_2 = (tempprof(i  )-tempprof(i+1))/(GPHprof(i+1)-GPHprof(i  ))
        lapse_3 = (tempprof(i+1)-tempprof(i+2))/(GPHprof(i+2)-GPHprof(i+1))
        if(lapse_1.gt.0.002.and.&
           lapse_2.lt.0.002.and.&
           lapse_3.lt.0.002)then
          TropoH = GPHprof(i)
          TropoT = tempprof(i)
          TropoP = p_fullmet_sp(i)
          exit
        endif
      enddo
      write(6,*)"Tropopause Height, Temp, Pressure"
      write(6,*)TropoH,TropoT,TropoP


      end subroutine GetMetProfile

!##############################################################################
!##############################################################################

      subroutine WriteGnuplotScript(inlon,inlat,inyear,inmonth,inday,inhour)

      implicit none

      real(kind=4) :: inlon,inlat
      integer :: inyear,inmonth,inday
      real(kind=8) :: inhour
      integer :: ihour
      character(len=47) :: string1,string2,string3,string4,string5

      if(inhour.lt.12)then
        ihour = 0
      else
        ihour = 12
      endif

      write(6,*)"WARNING:  Assuming sonde data in /data/WindFiles/MetProfiles/"

      write(string1,'(a33,i4,3i2.2,4a)')"/data/WindFiles/MetProfiles/PASY_",&
                                        inyear,inmonth,inday,ihour,".dat"
      write(string2,'(a33,i4,3i2.2,4a)')"/data/WindFiles/MetProfiles/PACD_",&
                                        inyear,inmonth,inday,ihour,".dat"
      write(string3,'(a33,i4,3i2.2,4a)')"/data/WindFiles/MetProfiles/PAKN_",&
                                        inyear,inmonth,inday,ihour,".dat"
      write(string4,'(a33,i4,3i2.2,4a)')"/data/WindFiles/MetProfiles/PADQ_",&
                                        inyear,inmonth,inday,ihour,".dat"
      write(string5,'(a33,i4,3i2.2,4a)')"/data/WindFiles/MetProfiles/PANC_",&
                                        inyear,inmonth,inday,ihour,".dat"

      open(unit=20,file='prof.gnu')

      write(20,*)"set terminal png size 600,600 xffffff x000000"
      write(20,*)"set key bmargin left vertical Right noreverse enhanced", &
                 " autotitles box linetype -1 linewidth 1.000"
      write(20,*)"set key at -20,17000"
      write(20,*)"set key font ',4'"
      write(20,*)"set key spacing 0.75"
      write(20,*)"set border 31 lw 2.0 lc rgb '#000000'"
      write(20,*)"set style line 1 linecolor rgbcolor '#FFA500' linewidth 4.0 pt 7"
      write(20,*)"set style line 2 linecolor rgbcolor '#880000' linewidth 1.0 pt 7"
      write(20,*)"set style line 3 linecolor rgbcolor '#888800' linewidth 1.0 pt 7"
      write(20,*)"set style line 4 linecolor rgbcolor '#008800' linewidth 1.0 pt 7"
      write(20,*)"set style line 5 linecolor rgbcolor '#008888' linewidth 1.0 pt 7"
      write(20,*)"set style line 6 linecolor rgbcolor '#000088' linewidth 1.0 pt 7"
      write(20,*)"set style line 7 linecolor rgbcolor '#0000FF' linewidth 4.0 pt 7"
      write(20,*)"set output 'prof.png'"
!      write(20,*)'set title "Atmospheric Profile Forecast for\n',&
!                 inlon,inlat,'\n',inyear,inmonth,inday,real(inhour,kind=4),' UTC"'
      write(20,2)inlon,inlat,inmonth,inday,inyear,inhour
2     format('set title "Atmospheric Temperature Profile Forecast for\n',&
             'lon=',f8.3,', lat=',f8.3,'\n',i2,'-',i2,'-',i4,1x,f4.1,' UTC"')

      write(20,*)"set format y '%.0f'; set ylabel 'Height (m)'"
      write(20,*)"set xlabel 'Temperature (C)'"
      write(20,*)"set grid"
      write(20,*)"plot [-70:20][0:20000] \"
      write(20,*)"  'GFS_prof.dat'        using 3:2 with lines ls 7 title 'Model-GFS', \"
      write(20,*)"  '",string1,"' using 3:2 with lines ls 2 title 'Shemya Afb', \"
      write(20,*)"  '",string2,"' using 3:2 with lines ls 3 title 'Cold Bay', \"
      write(20,*)"  '",string3,"' using 3:2 with lines ls 4 title 'King Salmon', \"
      write(20,*)"  '",string4,"' using 3:2 with lines ls 5 title 'Kodiak', \"
      write(20,*)"  '",string5,"' using 3:2 with lines ls 6 title 'Anchorage'"

      close(20)

      end subroutine WriteGnuplotScript


!##############################################################################
!##############################################################################

