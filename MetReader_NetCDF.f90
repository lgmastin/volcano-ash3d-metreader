!##############################################################################
!
!     MR_Read_Met_DimVars_netcdf
!
!     Called once from MR_Read_Met_DimVars 
!
!     This subroutine reads the variable and dimension IDs, and fills the
!     coordinate dimension variables
!
!     After this subroutine completes, the following variables will be set:
!       All the projection parameters of NWP grid
!       Met_dim_names, Met_var_names, Met_var_conversion_factor, Met_var_IsAvailable
!       The lengths of all the dimensions of the file
!       p_fullmet_sp (converted to Pa)
!       x_fullmet_sp, y_fullmet_sp
!       IsLatLon_MetGrid, IsGlobal_MetGrid, IsRegular_MetGrid 
!
!##############################################################################

      subroutine MR_Read_Met_DimVars_netcdf

      use MetReader
      use netcdf
      use projection

      implicit none

      integer, parameter :: sp        = 4 ! single precision
      integer, parameter :: dp        = 8 ! double precision

      integer :: i, k
      real(kind=sp) :: xLL_fullmet
      real(kind=sp) :: yLL_fullmet
      real(kind=sp) :: xUR_fullmet
      real(kind=sp) :: yUR_fullmet

      integer :: ncid
      integer :: ivar,in_var_id,var_ndims
      integer :: i_dim,iivar
      integer :: xdim_id, ydim_id, tdim_id
      integer :: dimlen,maxdimlen
      integer :: nSTAT
      character(len=NF90_MAX_NAME)  :: name,invar,dimname
      integer :: var_xtype,var_id,idx
      integer :: xtype, length, attnum

      integer :: NC_version
      integer,dimension(:),allocatable :: var_dimIDs
      logical :: FoundOldDim
      logical :: IsPressureDimension
      real(kind=dp),dimension(:), allocatable :: dum1d_dp
      real(kind=sp),dimension(:), allocatable :: dum1d_sp
      character(len=31)  :: ustring
      logical :: IsTruncatedDim

      write(MR_global_production,*)"--------------------------------------------------------------------------------"
      write(MR_global_production,*)"----------                MR_Read_Met_DimVars_netcdf                  ----------"
      write(MR_global_production,*)"--------------------------------------------------------------------------------"

      if(MR_iwindformat.ne.0)then
        Met_dim_names = ""
        Met_var_names = ""
        Met_var_conversion_factor(:)  = 1.0_sp
      endif

      ! Initialize dimension and variable names
      if(MR_iwindformat.eq.0)then
          ! This expects that MR_iwf_template has been filled by the calling program
        call MR_Read_Met_Template
      elseif(MR_iwindformat.eq.2)then
        ! This is reserved for reading Radiosonde data
      elseif(MR_iwindformat.eq.3)then
          ! NARR3D NAM221 32 km North America files (RAW : assumes full set of
          ! variables)
          ! Note that winds are "earth-relative" and must be rotated!
          ! See
          ! http://www.emc.ncep.noaa.gov/mmb/rreanl/faq.html#eta-winds
          ! https://rda.ucar.edu/datasets/ds608.0/
        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "reftime"     ! time
        Met_vardim_names(1) = "reftime"     ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "isobaric2" ! pressure
        Met_vardim_names(2) = "isobaric2" ! pressure
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "y"        ! y
        Met_vardim_names(3) = "y"        ! y
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "x"        ! x
        Met_vardim_names(4) = "x"        ! x
          Met_dim_IsAvailable(4)=.true.
        !Met_dim_names(5) = "isobaric2" ! pressure coordinate for Vz
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = "isobaric2" ! pressure coordinate for RH
        !  Met_dim_IsAvailable(6)=.true.

        ! Mechanical / State variables
        Met_var_names(1) = "Geopotential_height_isobaric" 
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "u_wind_isobaric"              
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "v_wind_isobaric"              
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "Pressure_vertical_velocity_isobaric"
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "Temp_isobaric"
          Met_var_IsAvailable(5)=.true.
        ! Surface
        Met_var_names(10)= "Planetary_boundary_layer_height"
          Met_var_IsAvailable(10)=.true.
        Met_var_names(11)= "u_wind_height_above_ground"
          Met_var_IsAvailable(11)=.true.
        Met_var_names(12)= "v_wind_height_above_ground"
          Met_var_IsAvailable(12)=.true.
        Met_var_names(13)= "Surface_friction_velocity_surface"
          Met_var_IsAvailable(13)=.true.
        Met_var_names(15) = "Snow_depth_surface"
          Met_var_IsAvailable(15)=.true.

        ! Atmospheric Structure
        Met_var_names(20) = "Pressure_cloud_base"
          Met_var_IsAvailable(20)=.true.
        Met_var_names(21) = "Pressure_cloud_tops"
          Met_var_IsAvailable(21)=.true.
        ! Moisture
        !Met_var_names(30) = "Relative_humidity_isobaric"
        !  Met_var_IsAvailable(30)=.true.
        Met_var_names(31) = "Specific_humidity_isobaric"
          Met_var_IsAvailable(31)=.true.
        Met_var_names(32) = "Cloud_water"
          Met_var_IsAvailable(32)=.true.
        Met_var_names(33) = "Ice_mixing_ratio"
          Met_var_IsAvailable(33)=.true.
        ! Precipitation
        Met_var_names(40) = "Categorical_rain_yes1_no0_surface"
          Met_var_IsAvailable(40)=.true.
        Met_var_names(41) = "Categorical_snow_yes1_no0_surface"
          Met_var_IsAvailable(41)=.true.
        Met_var_names(42) = "Categorical_freezing_rain_yes1_no0_surface"
          Met_var_IsAvailable(42)=.true.
        Met_var_names(43) = "Categorical_ice_pellets_yes1_no0_surface"
          Met_var_IsAvailable(43)=.true.
        Met_var_names(44) = "Precipitation_rate_surface"
          Met_var_IsAvailable(44)=.true.

        fill_value_sp(MR_iwindformat) = -9999.0_sp

      elseif(MR_iwindformat.eq.4)then
        ! NAM Regional North America 221 32 km North America files

        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "time"      ! time
        Met_vardim_names(1) = "time"      ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "isobaric3"  ! pressure
        Met_vardim_names(2) = "isobaric3"  ! pressure
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "y"         ! y
        Met_vardim_names(3) = "y"         ! y
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "x"         ! x
        Met_vardim_names(4) = "x"         ! x
          Met_dim_IsAvailable(4)=.true.
        !Met_dim_names(5) = "isobaric3" ! pressure coordinate for Vz
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = "isobaric3"  ! pressure coordinate for RH
        !  Met_dim_IsAvailable(6)=.true.

        ! Mechanical / State variables
        Met_var_names(1) = "Geopotential_height_isobaric"
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "u-component_of_wind_isobaric"
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "v-component_of_wind_isobaric"
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "Vertical_velocity_pressure_isobaric"
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "Temperature_isobaric"
          Met_var_IsAvailable(5)=.true.
        ! Surface
        Met_var_names(10) = "Planetary_Boundary_Layer_Height_surface"
          Met_var_IsAvailable(10)=.true.
        Met_var_names(11) = "u-component_of_wind_height_above_ground"
          Met_var_IsAvailable(11)=.true.
        Met_var_names(12) = "v-component_of_wind_height_above_ground"
          Met_var_IsAvailable(12)=.true.
        Met_var_names(13) = "Frictional_Velocity_surface"
          Met_var_IsAvailable(13)=.true.
        Met_var_names(16) = "Volumetric_Soil_Moisture_Content_depth_below_surface_layer"
          Met_var_IsAvailable(16)=.true.
        ! Atmospheric Structure
        Met_var_names(23) = "Total_cloud_cover_entire_atmosphere"
          Met_var_IsAvailable(23)=.true.
        ! Moisture
        Met_var_names(30) = "Relative_humidity_isobaric"
          Met_var_IsAvailable(30)=.true.
        Met_var_names(31) = "Specific_humidity_isobaric"
          Met_var_IsAvailable(31)=.true.
        Met_var_names(32) = "Cloud_mixing_ratio_isobaric"
          Met_var_IsAvailable(32)=.true.
        ! Precipitation
        Met_var_names(40) = "Categorical_Rain_surface"
          Met_var_IsAvailable(40)=.true.
        Met_var_names(41) = "Categorical_Snow_surface"
          Met_var_IsAvailable(41)=.true.
        Met_var_names(42) = "Categorical_Freezing_Rain_surface"
          Met_var_IsAvailable(42)=.true.
        Met_var_names(43) = "Categorical_Ice_Pellets_surface"
          Met_var_IsAvailable(43)=.true.
        Met_var_names(45) = "Convective_Precipitation_Rate_surface"
          Met_var_IsAvailable(45)=.true.

        fill_value_sp(MR_iwindformat) = -9999.0_sp ! actually NaNf

      elseif(MR_iwindformat.eq.5)then
          ! NAM216 AK 45km

        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "time1"      ! time
        Met_vardim_names(1) = "time1"      ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "isobaric1"  ! pressure
        Met_vardim_names(2) = "isobaric1"  ! pressure
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "y"         ! y
        Met_vardim_names(3) = "y"         ! y
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "x"         ! x
        Met_vardim_names(4) = "x"         ! x
          Met_dim_IsAvailable(4)=.true.
        !Met_dim_names(5) = "isobaric5" ! pressure coordinate for Vz
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = "isobaric1"  ! pressure coordinate for RH
        !  Met_dim_IsAvailable(6)=.true.

        ! Mechanical / State variables
        Met_var_names(1) = "Geopotential_height_isobaric"
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "u-component_of_wind_isobaric"
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "v-component_of_wind_isobaric"
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "Vertical_velocity_pressure_isobaric"
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "Temperature_isobaric"
          Met_var_IsAvailable(5)=.true.
        ! Surface
        Met_var_names(10) = "Planetary_Boundary_Layer_Height"
          Met_var_IsAvailable(10)=.true.
        Met_var_names(11) = "U-component_of_wind_height_above_ground"
          Met_var_IsAvailable(11)=.true.
        Met_var_names(12) = "V-component_of_wind_height_above_ground"
          Met_var_IsAvailable(12)=.true.
        Met_var_names(13) = "Frictional_Velocity"
          Met_var_IsAvailable(13)=.true.
        Met_var_names(16) = "Volumetric_Soil_Moisture_Content"
          Met_var_IsAvailable(14)=.true.
        ! Atmospheric Structure
        Met_var_names(23) = "Total_cloud_cover"
          Met_var_IsAvailable(23)=.true.
        ! Moisture
        Met_var_names(30) = "Relative_humidity"
          Met_var_IsAvailable(30)=.true.
        Met_var_names(31) = "Specific_humidity"
          Met_var_IsAvailable(31)=.true.
        Met_var_names(32) = "Cloud_mixing_ratio"
          Met_var_IsAvailable(32)=.true.
        ! Precipitation
        Met_var_names(40) = "Categorical_Rain"
          Met_var_IsAvailable(40)=.true.
        Met_var_names(41) = "Categorical_Snow"
          Met_var_IsAvailable(41)=.true.
        Met_var_names(42) = "Categorical_Freezing_Rain"
          Met_var_IsAvailable(42)=.true.
        Met_var_names(43) = "Categorical_Ice_Pellets"
          Met_var_IsAvailable(43)=.true.
        Met_var_names(44) = "Large_scale_precipitation_non-convective"
          Met_var_IsAvailable(44)=.true.
        Met_var_names(45) = "Convective_precipitation"
          Met_var_IsAvailable(45)=.true.

        fill_value_sp(MR_iwindformat) = -9999.0_sp ! actually NaNf

      elseif(MR_iwindformat.eq.6)then
          ! NAM Regional 90 km grid 104
        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "time"      ! time
        Met_vardim_names(1) = "time"      ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "isobaric"  ! pressure
        Met_vardim_names(2) = "isobaric"  ! pressure
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "y"         ! y
        Met_vardim_names(3) = "y"         ! y
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "x"         ! x
        Met_vardim_names(4) = "x"         ! x
          Met_dim_IsAvailable(4)=.true.
        !Met_dim_names(5) = "isobaric"  ! pressure coordinate for Vz
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = "isobaric1" ! pressure coordinate for RH
        !  Met_dim_IsAvailable(6)=.true.

        ! Mechanical / State variables
        Met_var_names(1) = "Geopotential_height_isobaric"    !        float 
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "u-component_of_wind_isobaric"    !        float 
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "v-component_of_wind_isobaric"    !        float 
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "Vertical_velocity_pressure_isobaric"  ! float
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "Temperature_isobaric"            !        float 
          Met_var_IsAvailable(5)=.true.
        ! Surface
        Met_var_names(11) = "u-component_of_wind_height_above_ground"
          Met_var_IsAvailable(11)=.true.
        Met_var_names(12) = "v-component_of_wind_height_above_ground"
          Met_var_IsAvailable(12)=.true.
        Met_var_names(13) = "Frictional_Velocity_surface"
          Met_var_IsAvailable(13)=.true.
        Met_var_names(16) = "Volumetric_Soil_Moisture_Content_depth_below_surface_layer"
          Met_var_IsAvailable(16)=.true.
        ! Atmospheric Structure
        Met_var_names(23) = "Total_cloud_cover_entire_atmosphere_0_Hour_Average"
          Met_var_IsAvailable(23)=.true.
        !Met_var_names(23) = "Low_cloud_cover_low_cloud"
        !  Met_var_IsAvailable(23)=.true.
        Met_var_names(24) = "Convective_cloud_cover_entire_atmosphere_0_Hour_Average"
          Met_var_IsAvailable(24)=.true.
        ! Moisture
        Met_var_names(30) = "Relative_humidity_isobaric"      !        float 
          Met_var_IsAvailable(30)=.true.
        Met_var_names(31) = "Specific_humidity_isobaric"
          Met_var_IsAvailable(31)=.true.
        Met_var_names(32) = "Cloud_mixing_ratio_isobaric"
          Met_var_IsAvailable(32)=.true.
        ! Precipitation
        Met_var_names(40) = "Categorical_Rain_surface"
          Met_var_IsAvailable(40)=.true.
        Met_var_names(41) = "Categorical_Snow_surface"
          Met_var_IsAvailable(41)=.true.
        Met_var_names(42) = "Categorical_Freezing_Rain_surface"
          Met_var_IsAvailable(42)=.true.
        Met_var_names(43) = "Categorical_Ice_Pellets_surface"
          Met_var_IsAvailable(43)=.true.
        Met_var_names(44) = "Large_scale_precipitation_non-convective_surface_0_Hour_Accumulation"
          Met_var_IsAvailable(44)=.true.
        Met_var_names(45) = "Convective_precipitation_surface_0_Hour_Accumulation"
          Met_var_IsAvailable(45)=.true.

        fill_value_sp(MR_iwindformat) = -9999.0_sp ! actually NaNf

      elseif(MR_iwindformat.eq.7)then
          ! CONUS 212 40km
        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "time1"     ! time
        Met_vardim_names(1) = "time1"     ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "isobaric3" ! pressure
        Met_vardim_names(2) = "isobaric3" ! pressure
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "y"        ! y
        Met_vardim_names(3) = "y"        ! y
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "x"        ! x
        Met_vardim_names(4) = "x"        ! x
          Met_dim_IsAvailable(4)=.true.
        !Met_dim_names(5) = "isobaric3" ! pressure coordinate for Vz
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = "isobaric3" ! pressure coordinate for RH
        !  Met_dim_IsAvailable(6)=.true.

        ! Mechanical / State variables
        Met_var_names(1) = "Geopotential_height_isobaric" !        float 
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "u-component_of_wind_isobaric" !        float 
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "v-component_of_wind_isobaric" !        float 
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "Vertical_velocity_pressure_isobaric" ! float Pa/s
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "Temperature_isobaric"         !        float
          Met_var_IsAvailable(5)=.true.
        ! Surface
        Met_var_names(10) = "Planetary_Boundary_Layer_Height_surface"
          Met_var_IsAvailable(10)=.true.
        Met_var_names(11) = "u-component_of_wind_height_above_ground"
          Met_var_IsAvailable(11)=.true.
        Met_var_names(12) = "v-component_of_wind_height_above_ground"
          Met_var_IsAvailable(12)=.true.
        Met_var_names(13) = "Frictional_Velocity_surface"
          Met_var_IsAvailable(13)=.true.
        !  14 = Displacement Height
        Met_var_names(15) = "Snow_depth_surface"
          Met_var_IsAvailable(15)=.true.
        Met_var_names(16) = "Volumetric_Soil_Moisture_Content_depth_below_surface_layer"
          Met_var_IsAvailable(16)=.true.
        ! Atmospheric Structure
        Met_var_names(23) = "Total_cloud_cover"
          Met_var_IsAvailable(23)=.true.
        !Met_var_names(23) = "Low_cloud_cover"
        !  Met_var_IsAvailable(23)=.true.
        Met_var_names(24) = "Convective_cloud_cover"
          Met_var_IsAvailable(24)=.true.
        ! Moisture
        Met_var_names(30) = "Relative_humidity_isobaric"      !        float 
          Met_var_IsAvailable(30)=.true.
        Met_var_names(31) = "Specific_humidity_isobaric"
          Met_var_IsAvailable(31)=.true.
        Met_var_names(32) = "Cloud_mixing_ratio_isobaric"
          Met_var_IsAvailable(32)=.true.
        ! Precipitation
        Met_var_names(40) = "Categorical_Rain_surface"
          Met_var_IsAvailable(40)=.true.
        Met_var_names(41) = "Categorical_Snow_surface"
          Met_var_IsAvailable(41)=.true.
        Met_var_names(42) = "Categorical_Freezing_Rain_surface"
          Met_var_IsAvailable(42)=.true.
        Met_var_names(43) = "Categorical_Ice_Pellets_surface"
          Met_var_IsAvailable(43)=.true.
        Met_var_names(45) = "Convective_Precipitation_Rate_surface"
          Met_var_IsAvailable(45)=.true.

        fill_value_sp(MR_iwindformat) = -9999.0_sp ! actually NaNf

      elseif(MR_iwindformat.eq.8)then
          ! CONUS 218 (12km)
          ! wget
          ! ftp://ftp.ncep.noaa.gov/pub/data/nccf/com/nam/prod/nam.20121231/nam.t00z.awphys${fh[$i]}.grb2.tm00

        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "time"     ! time
        Met_vardim_names(1) = "time"     ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "isobaric1" ! pressure
        Met_vardim_names(2) = "isobaric1" ! pressure
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "y"        ! y
        Met_vardim_names(3) = "y"        ! y
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "x"        ! x
        Met_vardim_names(4) = "x"        ! x
          Met_dim_IsAvailable(4)=.true.
        !Met_dim_names(5) = "isobaric1" ! pressure coordinate for Vz
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = "isobaric1" ! pressure coordinate for RH
        !  Met_dim_IsAvailable(6)=.true.

        ! Mechanical / State variables
        Met_var_names(1) = "Geopotential_height_isobaric" !        float 
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "u-component_of_wind_isobaric" !        float 
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "v-component_of_wind_isobaric" !        float 
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "Vertical_velocity_pressure_isobaric" ! float Pa/s
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "Temperature_isobaric"         !        float
          Met_var_IsAvailable(5)=.true.
        ! Surface
        Met_var_names(10) = "Planetary_Boundary_Layer_Height_surface"
          Met_var_IsAvailable(10)=.true.
        Met_var_names(11) = "u-component_of_wind_height_above_ground"
          Met_var_IsAvailable(11)=.true.
        Met_var_names(12) = "v-component_of_wind_height_above_ground"
          Met_var_IsAvailable(12)=.true.
        Met_var_names(13) = "Frictional_Velocity_surface"
          Met_var_IsAvailable(13)=.true.
        Met_var_names(15) = "Snow_depth_surface"
          Met_var_IsAvailable(15)=.true.
        Met_var_names(16) = "Volumetric_Soil_Moisture_Content_depth_below_surface_layer"
          Met_var_IsAvailable(16)=.true.
        ! Moisture
        Met_var_names(30) = "Relative_humidity_isobaric"   !        float 
          Met_var_IsAvailable(30)=.true.

        fill_value_sp(MR_iwindformat) = -9999.0_sp

      elseif(MR_iwindformat.eq.9)then
          ! CONUS 227 (5.08 km)

        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "time1"      ! time
        Met_vardim_names(1) = "time1"      ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "isobaric2" ! pressure
        Met_vardim_names(2) = "isobaric2" ! pressure
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "y"         ! y
        Met_vardim_names(3) = "y"         ! y
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "x"         ! x
        Met_vardim_names(4) = "x"         ! x
          Met_dim_IsAvailable(4)=.true.
        !Met_dim_names(5) = "isobaric2" ! pressure coordinate for Vz
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = "isobaric2" ! pressure coordinate for RH
        !  Met_dim_IsAvailable(6)=.true.

        ! Mechanical / State variables
        Met_var_names(1) = "Geopotential_height_isobaric" !        float 
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "u-component_of_wind_isobaric" !        float 
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "v-component_of_wind_isobaric" !        float 
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "Vertical_velocity_pressure_isobaric" ! float Pa/s
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "Temperature_isobaric"         !        float
          Met_var_IsAvailable(5)=.true.
        ! Surface
        Met_var_names(10) = "Planetary_Boundary_Layer_Height_surface"
          Met_var_IsAvailable(10)=.true. 
        Met_var_names(11) = "u-component_of_wind_height_above_ground"
          Met_var_IsAvailable(11)=.true. 
        Met_var_names(12) = "v-component_of_wind_height_above_ground"
          Met_var_IsAvailable(12)=.true. 
        Met_var_names(13) = "Frictional_Velocity_surface"
          Met_var_IsAvailable(13)=.true. 
        Met_var_names(15) = "Snow_depth_surface" 
          Met_var_IsAvailable(15)=.true.
        Met_var_names(16) = "Volumetric_Soil_Moisture_Content_depth_below_surface_layer"
          Met_var_IsAvailable(16)=.true.
        ! Moisture
        Met_var_names(30) = "Relative_humidity_isobaric"   !        float 
          Met_var_IsAvailable(30)=.true. 
        Met_var_names(31) = "Specific_humidity_isobaric"
          Met_var_IsAvailable(31)=.true.
        Met_var_names(32) = "Cloud_mixing_ratio_isobaric" ! isobaric3
          Met_var_IsAvailable(32)=.true.
        Met_var_names(33) = "Snow_mixing_ratio_isobaric" ! isobaric3
          Met_var_IsAvailable(33)=.true.
        ! Precipitation
        Met_var_names(40) = "Categorical_Rain_surface"
          Met_var_IsAvailable(40)=.true.
        Met_var_names(41) = "Categorical_Snow_surface"
          Met_var_IsAvailable(41)=.true.
        Met_var_names(42) = "Categorical_Freezing_Rain_surface"
          Met_var_IsAvailable(42)=.true.
        Met_var_names(43) = "Categorical_Ice_Pellets_surface"
          Met_var_IsAvailable(43)=.true.
        Met_var_names(44) = "Precipitation_rate_surface" !kg/m2/s
          Met_var_IsAvailable(44)=.true.

        fill_value_sp(MR_iwindformat) = -9999.0_sp

      elseif(MR_iwindformat.eq.10)then
          ! NAM 242 11.25 km AK

        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "time"      ! time
        Met_vardim_names(1) = "time"      ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "isobaric2"  ! pressure
        Met_vardim_names(2) = "isobaric2"  ! pressure
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "y"         ! y
        Met_vardim_names(3) = "y"         ! y
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "x"         ! x
        Met_vardim_names(4) = "x"         ! x
          Met_dim_IsAvailable(4)=.true.
        !Met_dim_names(5) = "isobaric1"  ! pressure coordinate for Vz
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = "isobaric2" ! pressure coordinate for RH
        !  Met_dim_IsAvailable(6)=.true.

        ! Mechanical / State variables
        Met_var_names(1) = "Geopotential_height_isobaric"    !        float 
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "u-component_of_wind_isobaric"    !        float 
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "v-component_of_wind_isobaric"    !        float 
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "Vertical_velocity_pressure_isobaric"  ! float
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "Temperature_isobaric"            !        float 
          Met_var_IsAvailable(5)=.true.
        ! Surface
        Met_var_names(10) = "Planetary_Boundary_Layer_Height_surface"
          Met_var_IsAvailable(10)=.true.
        Met_var_names(11) = "u-component_of_wind_height_above_ground"
          Met_var_IsAvailable(11)=.true.
        Met_var_names(12) = "v-component_of_wind_height_above_ground"
          Met_var_IsAvailable(12)=.true.
        ! Atmospheric Structure
        Met_var_names(23) = "Total_cloud_cover_entire_atmosphere"
          Met_var_IsAvailable(23)=.true.
        ! Moisture
        Met_var_names(30) = "Relative_humidity_isobaric"      !        float 
          Met_var_IsAvailable(30)=.true.
        ! Precipitation
        Met_var_names(40) = "Categorical_Rain_surface"
          Met_var_IsAvailable(40)=.true.
        Met_var_names(41) = "Categorical_Snow_surface"
          Met_var_IsAvailable(41)=.true.
        Met_var_names(42) = "Categorical_Freezing_Rain_surface"
          Met_var_IsAvailable(42)=.true.
        Met_var_names(43) = "Categorical_Ice_Pellets_surface"
          Met_var_IsAvailable(43)=.true.
        Met_var_names(44) = "Total_precipitation_surface_0_Hour_Accumulation"
          Met_var_IsAvailable(44)=.true.
        Met_var_names(45) = "Convective_precipitation_surface_0_Hour_Accumulation"
          Met_var_IsAvailable(45)=.true.

        fill_value_sp(MR_iwindformat) = -9999.0_sp ! actually NaNf

      elseif(MR_iwindformat.eq.11)then
          ! NAM 196 2.5 km HI

        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "time"      ! time
        Met_vardim_names(1) = "time"      ! time
          Met_dim_IsAvailable(1)=.true. 
        Met_dim_names(2) = "isobaric2"  ! pressure
        Met_vardim_names(2) = "isobaric2"  ! pressure
          Met_dim_IsAvailable(2)=.true. 
        Met_dim_names(3) = "y"         ! y
        Met_vardim_names(3) = "y"         ! y
          Met_dim_IsAvailable(3)=.true. 
        Met_dim_names(4) = "x"         ! x
        Met_vardim_names(4) = "x"         ! x
          Met_dim_IsAvailable(4)=.true. 
        !Met_dim_names(5) = "isobaric2"  ! pressure coordinate for Vz
        !  Met_dim_IsAvailable(5)=.true. 
        !Met_dim_names(6) = "isobaric2" ! pressure coordinate for RH
        !  Met_dim_IsAvailable(6)=.true. 

        ! Mechanical / State variables
        Met_var_names(1) = "Geopotential_height_isobaric"    !        float 
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "u-component_of_wind_isobaric"    !        float 
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "v-component_of_wind_isobaric"    !        float 
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "Vertical_velocity_pressure_isobaric"  ! float
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "Temperature_isobaric"            !        float 
          Met_var_IsAvailable(5)=.true.

        ! Surface
        Met_var_names(10) = "Planetary_Boundary_Layer_Height_surface"
          Met_var_IsAvailable(10)=.true.
        Met_var_names(11) = "u-component_of_wind_height_above_ground"
          Met_var_IsAvailable(11)=.true.
        Met_var_names(12) = "v-component_of_wind_height_above_ground"
          Met_var_IsAvailable(12)=.true.
        Met_var_names(13) = "Frictional_Velocity_surface"
          Met_var_IsAvailable(13)=.true.
        !  14 = Displacement Height
        Met_var_names(15) = "Snow_Cover_surface"
          Met_var_IsAvailable(15)=.true.
        Met_var_names(16) = "Soil_moisture_content_depth_below_surface_layer"
          Met_var_IsAvailable(16)=.true.
        Met_var_names(17) = "Surface_roughness_surface"
          Met_var_IsAvailable(17)=.true.
        ! Atmospheric Structure
        Met_var_names(20) = "Pressure_cloud_base"
          Met_var_IsAvailable(20)=.true.
        Met_var_names(21) = "Pressure_cloud_tops"
          Met_var_IsAvailable(21)=.true.
        Met_var_names(23) = "Total_cloud_cover_entire_atmosphere"
          Met_var_IsAvailable(23)=.true.
        ! Moisture
        Met_var_names(30) = "Relative_humidity_isobaric"      !        float 
          Met_var_IsAvailable(30)=.true.
        Met_var_names(31) = "Specific_humidity_isobaric"
          Met_var_IsAvailable(31)=.true.
        Met_var_names(32) = "Cloud_mixing_ratio_isobaric" ! isobaric3
          Met_var_IsAvailable(32)=.true.
        Met_var_names(33) = "Snow_mixing_ratio_isobaric" ! isobaric3
          Met_var_IsAvailable(33)=.true.
        ! Precipitation
        Met_var_names(40) = "Categorical_Rain_surface"
          Met_var_IsAvailable(40)=.true.
        Met_var_names(41) = "Categorical_Snow_surface"
          Met_var_IsAvailable(41)=.true.
        Met_var_names(42) = "Categorical_Freezing_Rain_surface"
          Met_var_IsAvailable(42)=.true.
        Met_var_names(43) = "Categorical_Ice_Pellets_surface"
          Met_var_IsAvailable(43)=.true.
        Met_var_names(44) = "Precipitation_rate_surface" !kg/m2/s
          Met_var_IsAvailable(44)=.true.

        fill_value_sp(MR_iwindformat) = -9999.0_sp ! actually NaNf

      elseif(MR_iwindformat.eq.12)then
          ! NAM 198 5.953 km AK

        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.  

        Met_dim_names(1) = "time"      ! time
        Met_vardim_names(1) = "time"      ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "isobaric2"  ! pressure
        Met_vardim_names(2) = "isobaric2"  ! pressure
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "y"         ! y
        Met_vardim_names(3) = "y"         ! y
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "x"         ! x
        Met_vardim_names(4) = "x"         ! x
          Met_dim_IsAvailable(4)=.true.
        !Met_dim_names(5) = "isobaric2"  ! pressure coordinate for Vz
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = "isobaric2" ! pressure coordinate for RH
        !  Met_dim_IsAvailable(6)=.true.

        ! Mechanical / State variables
        Met_var_names(1) = "Geopotential_height_isobaric"    !        float 
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "u-component_of_wind_isobaric"    !        float 
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "v-component_of_wind_isobaric"    !        float 
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "Vertical_velocity_pressure_isobaric"  ! float
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "Temperature_isobaric"            !        float 
          Met_var_IsAvailable(5)=.true.
        ! Surface
        Met_var_names(10) = "Planetary_Boundary_Layer_Height_surface"
          Met_var_IsAvailable(10)=.true.
        Met_var_names(11) = "u-component_of_wind_height_above_ground"
          Met_var_IsAvailable(11)=.true.
        Met_var_names(12) = "v-component_of_wind_height_above_ground"
          Met_var_IsAvailable(12)=.true.
        Met_var_names(13) = "Frictional_Velocity_surface"
          Met_var_IsAvailable(13)=.true.
        Met_var_names(15) = "Snow_depth_surface"
          Met_var_IsAvailable(15)=.true.
        Met_var_names(16) = "Soil_moisture_content_depth_below_surface_layer"
          Met_var_IsAvailable(16)=.true.
        Met_var_names(17) = "Surface_roughness_surface"
          Met_var_IsAvailable(17)=.true.
        Met_var_names(18) = "Wind_speed_gust_surface"
          Met_var_IsAvailable(18)=.true.
        ! Atmospheric Structure
        Met_var_names(20) = "Pressure_cloud_base"
          Met_var_IsAvailable(20)=.true.
        Met_var_names(21) = "Pressure_cloud_tops"
          Met_var_IsAvailable(21)=.true.
        Met_var_names(23) = "Total_cloud_cover_entire_atmosphere"
          Met_var_IsAvailable(23)=.true.
        ! Moisture
        Met_var_names(30) = "Relative_humidity_isobaric"      !        float 
          Met_var_IsAvailable(30)=.true.
        Met_var_names(31) = "Specific_humidity_isobaric"
          Met_var_IsAvailable(31)=.true.
        Met_var_names(32) = "Cloud_mixing_ratio_isobaric" ! isobaric3
          Met_var_IsAvailable(32)=.true.
        Met_var_names(33) = "Snow_mixing_ratio_isobaric" ! isobaric3
          Met_var_IsAvailable(33)=.true.
        ! Precipitation
        Met_var_names(40) = "Categorical_Rain_surface"
          Met_var_IsAvailable(40)=.true.
        Met_var_names(41) = "Categorical_Snow_surface"
          Met_var_IsAvailable(41)=.true.
        Met_var_names(42) = "Categorical_Freezing_Rain_surface"
          Met_var_IsAvailable(42)=.true.
        Met_var_names(43) = "Categorical_Ice_Pellets_surface"
          Met_var_IsAvailable(43)=.true.
        Met_var_names(44) = "Precipitation_rate_surface" !kg/m2/s
          Met_var_IsAvailable(44)=.true.
        Met_var_names(45) = "Convective_precipitation_surface_0_Hour_Accumulation" !kg/m2 or
          Met_var_IsAvailable(45)=.true.

        fill_value_sp(MR_iwindformat) = -9999.0_sp ! actually NaNf

      elseif(MR_iwindformat.eq.13)then
          ! NAM 91 2.976 km AK
          ! Note: the dimension names given below are those generated by netcdf-java 4.5
          !       acting on the truncated grib files generated by get_nam91.sh which 
          !       uses get_inv.pl to get just the grib layers needed.
          !       This is relavent because the numbering of the isobaric dimensions
          !       appears to be in the order they are processed in the grib file
        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "time"      ! time
        Met_vardim_names(1) = "time"      ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "isobaric"  ! pressure
        Met_vardim_names(2) = "isobaric"  ! pressure
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "y"         ! y
        Met_vardim_names(3) = "y"         ! y
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "x"         ! x
        Met_vardim_names(4) = "x"         ! x
          Met_dim_IsAvailable(4)=.true.
        !Met_dim_names(5) = "isobaric"  ! pressure coordinate for Vz
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = "isobaric" ! pressure coordinate for RH
        !  Met_dim_IsAvailable(6)=.true.

        ! Mechanical / State variables
        Met_var_names(1) = "Geopotential_height_isobaric"    !        float 
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "u-component_of_wind_isobaric"    !        float 
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "v-component_of_wind_isobaric"    !        float 
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "Vertical_velocity_pressure_isobaric"  ! float
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "Temperature_isobaric"            !        float 
          Met_var_IsAvailable(5)=.true.
        ! Surface
        Met_var_names(10) = "Planetary_Boundary_Layer_Height_surface"
          Met_var_IsAvailable(10)=.true.
        Met_var_names(11) = "u-component_of_wind_height_above_ground"
          Met_var_IsAvailable(11)=.true.
        Met_var_names(12) = "v-component_of_wind_height_above_ground"
          Met_var_IsAvailable(12)=.true.
        Met_var_names(13) = "Frictional_Velocity_surface"
          Met_var_IsAvailable(13)=.true.
        Met_var_names(15) = "Snow_depth_surface"
          Met_var_IsAvailable(15)=.true.
        Met_var_names(16) = "Volumetric_Soil_Moisture_Content_depth_below_surface_layer"
          Met_var_IsAvailable(16)=.true.
        Met_var_names(17) = "Surface_roughness_surface"
          Met_var_IsAvailable(17)=.true.
        Met_var_names(18) = "Wind_speed_gust_surface"
          Met_var_IsAvailable(18)=.true.
        ! Moisture
        Met_var_names(30) = "Relative_humidity_isobaric"      !        float 
          Met_var_IsAvailable(30)=.true.
        Met_var_names(31) = "Specific_humidity_isobaric"
          Met_var_IsAvailable(31)=.true.
        Met_var_names(32) = "Cloud_mixing_ratio_isobaric" ! isobaric1
          Met_var_IsAvailable(32)=.true.
        Met_var_names(33) = "Snow_mixing_ratio_isobaric" ! isobaric1
          Met_var_IsAvailable(33)=.true.
        ! Precipitation
        Met_var_names(40) = "Categorical_Rain_surface"
          Met_var_IsAvailable(40)=.true.
        Met_var_names(41) = "Categorical_Snow_surface"
          Met_var_IsAvailable(41)=.true.
        Met_var_names(42) = "Categorical_Freezing_Rain_surface"
          Met_var_IsAvailable(42)=.true.
        Met_var_names(43) = "Categorical_Ice_Pellets_surface"
          Met_var_IsAvailable(43)=.true.
        Met_var_names(44) = "Precipitation_rate_surface" !kg/m2/s
          Met_var_IsAvailable(44)=.true.

        fill_value_sp(MR_iwindformat) = -9999.0_sp ! actually NaNf

      elseif(MR_iwindformat.eq.14)then
          ! CONUS 1227 (3.0 km)

        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "time1"      ! time
        Met_vardim_names(1) = "time1"      ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "isobaric2" ! pressure
        Met_vardim_names(2) = "isobaric2" ! pressure
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "y"         ! y
        Met_vardim_names(3) = "y"         ! y
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "x"         ! x
        Met_vardim_names(4) = "x"         ! x
          Met_dim_IsAvailable(4)=.true.
        !Met_dim_names(5) = "isobaric2" ! pressure coordinate for Vz
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = "isobaric2" ! pressure coordinate for RH
        !  Met_dim_IsAvailable(6)=.true.

        ! Mechanical / State variables
        Met_var_names(1) = "Geopotential_height_isobaric" !        float 
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "u-component_of_wind_isobaric" !        float 
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "v-component_of_wind_isobaric" !        float 
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "Vertical_velocity_pressure_isobaric" ! float Pa/s
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "Temperature_isobaric"         !        float
          Met_var_IsAvailable(5)=.true.
        ! Surface
        Met_var_names(10) = "Planetary_Boundary_Layer_Height_surface"
          Met_var_IsAvailable(10)=.true.
        Met_var_names(11) = "u-component_of_wind_height_above_ground"
          Met_var_IsAvailable(11)=.true.
        Met_var_names(12) = "v-component_of_wind_height_above_ground"
          Met_var_IsAvailable(12)=.true.
        Met_var_names(13) = "Frictional_Velocity_surface"
          Met_var_IsAvailable(13)=.true.
        Met_var_names(15) = "Snow_depth_surface"
          Met_var_IsAvailable(15)=.true.
        Met_var_names(16) = "Volumetric_Soil_Moisture_Content_depth_below_surface_layer"
          Met_var_IsAvailable(16)=.true.
        ! Moisture
        Met_var_names(30) = "Relative_humidity_isobaric"   !        float 
          Met_var_IsAvailable(30)=.true.
        Met_var_names(31) = "Specific_humidity_isobaric"
          Met_var_IsAvailable(31)=.true.
        Met_var_names(32) = "Cloud_mixing_ratio_isobaric" ! isobaric3
          Met_var_IsAvailable(32)=.true.
        Met_var_names(33) = "Snow_mixing_ratio_isobaric" ! isobaric3
          Met_var_IsAvailable(33)=.true.
        ! Precipitation
        Met_var_names(40) = "Categorical_Rain_surface"
          Met_var_IsAvailable(40)=.true.
        Met_var_names(41) = "Categorical_Snow_surface"
          Met_var_IsAvailable(41)=.true.
        Met_var_names(42) = "Categorical_Freezing_Rain_surface"
          Met_var_IsAvailable(42)=.true.
        Met_var_names(43) = "Categorical_Ice_Pellets_surface"
          Met_var_IsAvailable(43)=.true.
        Met_var_names(44) = "Precipitation_rate_surface" !kg/m2/s
          Met_var_IsAvailable(44)=.true.

        fill_value_sp(MR_iwindformat) = -9999.0_sp

      elseif (MR_iwindformat.eq.20.or.MR_iwindformat.eq.22) then
           ! GFS 0.5 (or 0.25) deg from http://www.nco.ncep.noaa.gov/pmb/products/gfs/
           ! or
           ! http://motherlode.ucar.edu/native/conduit/data/nccf/com/gfs/prod/
        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "time"       ! time
        Met_vardim_names(1) = "time"       ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "isobaric3"   ! pressure (1.0e5-1.0e3 Pa or 1000 -> 10.0 hPa in 26 levels)
        Met_vardim_names(2) = "isobaric3"   ! pressure (1.0e5-1.0e3 Pa or 1000 -> 10.0 hPa in 26 levels)
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "lat"        ! y        (90.0 -> -90.0)
        Met_vardim_names(3) = "lat"        ! y        (90.0 -> -90.0)
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "lon"        ! x        (0.0 - 359.5)
        Met_vardim_names(4) = "lon"        ! x        (0.0 - 359.5)
          Met_dim_IsAvailable(4)=.true.
        !Met_dim_names(5) = "isobaric4"  ! pressure coordinate for Vz (to 100 hPa in 21 levels)
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = "isobaric3"  ! pressure coordinate for RH (to 10 hPa in 25 levels)
        !  Met_dim_IsAvailable(6)=.true.

        ! Momentum / State variables
        Met_var_names(1) = "Geopotential_height_isobaric"    ! float gpm
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "u-component_of_wind_isobaric"    ! float m/s
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "v-component_of_wind_isobaric"    ! float m/s
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "Vertical_velocity_pressure_isobaric" ! float Pa/s
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "Temperature_isobaric"            ! float deg K
          Met_var_IsAvailable(5)=.true.

        ! Surface
        Met_var_names(10) = "Planetary_Boundary_Layer_Height_surface"
          Met_var_IsAvailable(10)=.true.
        Met_var_names(11) = "U-component_of_wind_height_above_ground" !(time, height_above_ground, lat, lon) 10, 80, 100
          Met_var_IsAvailable(11)=.true.
        Met_var_names(12) = "V-component_of_wind_height_above_ground"
          Met_var_IsAvailable(12)=.true.
        ! Atmospheric Structure
        Met_var_names(22) = "Cloud_Top_Temperature"
          Met_var_IsAvailable(22)=.true.
        Met_var_names(23) = "Total_cloud_cover"
          Met_var_IsAvailable(23)=.true.
        ! Moisture
        Met_var_names(30) = "Relative_humidity_isobaric"      ! float percent
          Met_var_IsAvailable(30)=.true.
        Met_var_names(32) = "Cloud_mixing_ratio"     ! float kg/kg
          Met_var_IsAvailable(32)=.true.
        ! Precipitation
        Met_var_names(40) = "Categorical_Rain"
          Met_var_IsAvailable(40)=.true.
        Met_var_names(41) = "Categorical_Snow"
          Met_var_IsAvailable(41)=.true.
        Met_var_names(42) = "Categorical_Freezing_Rain"
          Met_var_IsAvailable(42)=.true.
        Met_var_names(43) = "Categorical_Ice_Pellets"
          Met_var_IsAvailable(43)=.true.
        Met_var_names(44) = "Precipitation_rate"     ! float liquid surface precip kg/m2/s
          Met_var_IsAvailable(44)=.true.
        Met_var_names(45) = "Convective_Precipitation_Rate"       ! float liquid convective precip kg/m2/s
          Met_var_IsAvailable(45)=.true.

        fill_value_sp(MR_iwindformat) = -9999.0_sp

      elseif (MR_iwindformat.eq.21) then
           ! GFS 1.0 deg from http://www.nco.ncep.noaa.gov/pmb/products/gfs/
        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "time"       ! time
        Met_vardim_names(1) = "time"       ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "isobaric3"   ! pressure (1.0e5-1.0e3 Pa or 1000 -> 10.0 hPa in 26 levels)
        Met_vardim_names(2) = "isobaric3"   ! pressure (1.0e5-1.0e3 Pa or 1000 -> 10.0 hPa in 26 levels)
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "lat"        ! y        (90.0 -> -90.0)
        Met_vardim_names(3) = "lat"        ! y        (90.0 -> -90.0)
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "lon"        ! x        (0.0 - 359.5)
        Met_vardim_names(4) = "lon"        ! x        (0.0 - 359.5)
          Met_dim_IsAvailable(4)=.true.
        !Met_dim_names(5) = "isobaric2"  ! pressure coordinate for Vz (to 100 hPa in 21 levels)
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = "isobaric3"  ! pressure coordinate for RH (to 10 hPa in 25 levels)
        !  Met_dim_IsAvailable(6)=.true.

        ! Momentum / State variables
        Met_var_names(1) = "Geopotential_height_isobaric"    ! float gpm
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "u-component_of_wind_isobaric"    ! float m/s
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "v-component_of_wind_isobaric"    ! float m/s
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "Vertical_velocity_pressure_isobaric" ! float Pa/s
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "Temperature_isobaric"            ! float deg K
          Met_var_IsAvailable(5)=.true.

        ! Surface
        Met_var_names(10) = "Planetary_Boundary_Layer_Height_surface"
          Met_var_IsAvailable(10)=.true.
        ! Moisture
        Met_var_names(30) = "Relative_humidity_isobaric"      ! float percent
          Met_var_IsAvailable(30)=.true.
        Met_var_names(32) = "Cloud_mixing_ratio_isobaric"     ! float kg/kg
          Met_var_IsAvailable(32)=.true.

        fill_value_sp(MR_iwindformat) = -9999.0_sp

       elseif (MR_iwindformat.eq.23) then
         ! NCEP / DOE reanalysis 2.5 degree files 
         ! https://rda.ucar.edu/datasets/ds091.0

        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "time"       ! time
        Met_vardim_names(1) = "time"       ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "isobaric"   ! pressure (1000 -> 10 hPa in 17 levels)
        Met_vardim_names(2) = "isobaric"   ! pressure (1000 -> 10 hPa in 17 levels)
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "lat"        ! y        (90.0 -> -90.0)
        Met_vardim_names(3) = "lat"        ! y        (90.0 -> -90.0)
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "lon"        ! x        (0.0 -> 375.5)
        Met_vardim_names(4) = "lon"        ! x        (0.0 -> 375.5)
          Met_dim_IsAvailable(4)=.true.
        !Met_dim_names(5) = "isobaric"   ! pressure coordinate for Vz
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = "isobaric"   ! pressure coordinate for RH
        !  Met_dim_IsAvailable(6)=.true.

        ! Momentum / State variables
        Met_var_names(1) = "Geopotential_height_isobaric"        ! float m^2/s^2
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "u-component_of_wind_isobaric"       ! float m/s
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "v-component_of_wind_isobaric"       ! float m/s
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "Vertical_velocity_isobaric"       ! float Pa/s
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "Temperature_isobaric"        ! float K
          Met_var_IsAvailable(5)=.true.
        ! Moisture
        Met_var_names(30) = "Relative_humidity_isobaric"         ! float percent
          Met_var_IsAvailable(30)=.true.
        ! Precipitation
        Met_var_names(44) = "Precipitation_rate_surface"         ! float kg/m2/s (all 0's)
          Met_var_IsAvailable(44)=.true.

        fill_value_sp(MR_iwindformat) = 9.999_sp

       elseif (MR_iwindformat.eq.24) then
         ! NASA-MERRA-2 reanalysis 0.625 x 0.5 degree files 

        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "time"       ! time
        Met_vardim_names(1) = "time"       ! time
          Met_dim_IsAvailable(1)=.true. 
        Met_dim_names(2) = "lev"   ! pressure (1000 -> 0.1 hPa in 42 levels)
        Met_vardim_names(2) = "lev"   ! pressure (1000 -> 0.1 hPa in 42 levels)
          Met_dim_IsAvailable(2)=.true. 
        Met_dim_names(3) = "lat"        ! y        (89.375 -> -89.375)
        Met_vardim_names(3) = "lat"        ! y        (89.375 -> -89.375)
          Met_dim_IsAvailable(3)=.true. 
        Met_dim_names(4) = "lon"        ! x        (-179.375 -> 179.375)
        Met_vardim_names(4) = "lon"        ! x        (-179.375 -> 179.375)
          Met_dim_IsAvailable(4)=.true. 
        !Met_dim_names(5) = "lev"   ! pressure coordinate for Vz
        !  Met_dim_IsAvailable(5)=.true. 
        !Met_dim_names(6) = "lev"   ! pressure coordinate for RH
        !  Met_dim_IsAvailable(6)=.true. 

        Met_dim_fac(1) = 1.0/60.0

        ! Momentum / State variables
        ! Available in MERRA2_400.inst3_3d_asm_Np.YYYYMMDD.nc4
        !  from https://goldsmr5.gesdisc.eosdis.nasa.gov/data/MERRA2/M2I3NPASM.5.12.4
        Met_var_names(1) = "H"            ! float m^2/s^2
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "U"            ! float m/s
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "V"            ! float m/s
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "OMEGA"        ! float Pa/s
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "T"            ! float K
          Met_var_IsAvailable(5)=.true.

        ! Surface
        !Met_var_names(10) = "PBLH"        ! float Planetary boundary layer height (m)
        !  Met_var_IsAvailable(10)=.true.
        !Met_var_names(11) = "U10M"
        !  Met_var_IsAvailable(11)=.true.
        !Met_var_names(12) = "V10M"
        !  Met_var_IsAvailable(12)=.true.
        !Met_var_names(14) = "DISPH"
        !  Met_var_IsAvailable(14)=.true.
        !Met_var_names(16) = "GWETTOP"
        !  Met_var_IsAvailable(16)=.true.
        !Met_var_names(19) = "TS"
        !  Met_var_IsAvailable(19)=.true.
        !! Atmospheric Structure
        !Met_var_names(21) = "CLDPRS"
        !  Met_var_IsAvailable(21)=.true.
        !Met_var_names(22) = "CLDTMP"
        !  Met_var_IsAvailable(22)=.true.
        !Met_var_names(23) = "CLDTOT"
        !  Met_var_IsAvailable(23)=.true.
        !Met_var_names(24) = "CLDLOW"
        !  Met_var_IsAvailable(24)=.true.

        ! Moisture
        ! Available in MERRA2_400.inst3_3d_asm_Np.YYYYMMDD.nc4
        !  from https://goldsmr5.gesdisc.eosdis.nasa.gov/data/MERRA2/M2I3NPASM.5.12.4
        Met_var_names(30) = "RH"          ! float percent
          Met_var_IsAvailable(30)=.true.
        Met_var_names(31) = "QV"          ! float cloud liquid water mixing ratio kg/kg
          Met_var_IsAvailable(31)=.true.
        Met_var_names(32) = "QL"          ! float cloud liquid water mixing ratio kg/kg
          Met_var_IsAvailable(32)=.true.
        Met_var_names(33) = "QI"          ! float cloud ice mixing ratio kg/kg
          Met_var_IsAvailable(33)=.true.

        ! Precipitation: Note:This is on a different time grid 90 minutes offset
        ! Available in MERRA2_400.tavg3_3d_mst_Np.YYYYMMDD.nc4
        !  from https://goldsmr5.gesdisc.eosdis.nasa.gov/data/MERRA2/M2T3NPMST.5.12.4/
        !Met_var_names(44) = "PFLLSAN"     ! float liquid large-scale + anvil precip kg/m2/s
        !  Met_var_IsAvailable(44)=.true.
        !Met_var_names(45) = "PFLCU"       ! float liquid convective precip kg/m2/s
        !  Met_var_IsAvailable(45)=.true.
        !Met_var_names(46) = "PFILSAN"     ! float ice large-scale + anvil precip kg/m2/s
        !  Met_var_IsAvailable(46)=.true.
        !Met_var_names(47) = "PFICU"       ! float ice convective precip kg/m2/s
        !  Met_var_IsAvailable(47)=.true.

        fill_value_sp(MR_iwindformat) = 1.0e15_sp

        !Met_var_conversion_factor(44) = 1.0_sp/1.0e3_sp

       elseif (MR_iwindformat.eq.25) then
         ! NCEP/NCAR reanalysis 2.5 degree files 
         ! https://rda.ucar.edu/datasets/ds090.0

        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "time"       ! time
        Met_vardim_names(1) = "time"       ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "level"      ! pressure (17 levels 1000 -> 10)
        Met_vardim_names(2) = "level"      ! pressure (17 levels 1000 -> 10)
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "lat"        ! y        (90.0 -> -90.0)
        Met_vardim_names(3) = "lat"        ! y        (90.0 -> -90.0)
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "lon"        ! x        (0.0 -> 357.5)
        Met_vardim_names(4) = "lon"        ! x        (0.0 -> 357.5)
          Met_dim_IsAvailable(4)=.true.
        !Met_dim_names(5) = "level"      ! pressure coordinate for Vz (12 levels 1000 -> 100)
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = "level"      ! pressure coordinate for RH (8 levels 1000 -> 300)
        !  Met_dim_IsAvailable(6)=.true.

        ! Momentum / State variables
        Met_var_names(1) = "hgt"        ! short m^2/s^2 (32066.f,1.f)
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "uwnd"       ! short m/s (202.66f,0.01f)
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "vwnd"       ! short m/s (202.66f,0.01f)
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "omega"      ! short Pa/s (29.765f,0.001f)
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "air"        ! short K (477.66f,0.01f)
          Met_var_IsAvailable(5)=.true.
        ! Atmospheric Structure
        Met_var_names(20) = "pres"      ! short pres at low cloud bottom Pa(327650.f,10.f)
          Met_var_IsAvailable(20)=.true.
        Met_var_names(21) = "pres"      ! short pres at low cloud top Pa(327650.f,10.f)
          Met_var_IsAvailable(21)=.true.
        ! Moisture
        Met_var_names(30) = "rhum"       ! short  (302.66f,0.01f)
          Met_var_IsAvailable(30)=.true.
        Met_var_names(31) = "shum"      ! short SpecHum ~ mixing ratio kg/kg(0.032666f,1.e-06f)
          Met_var_IsAvailable(31)=.true.
        Met_var_names(32) = "shum"      ! short should really be QL (liquid)
          Met_var_IsAvailable(32)=.true.
        ! Precipitation
        Met_var_names(44) = "prate"      ! short surface precipitation rate (kg/m2/s) (0.0032765f,1.e-07f)
          Met_var_IsAvailable(44)=.true.
        Met_var_names(45) = "cprat"     ! short surface convective precip kg/m2/s (0.0031765f,1.e-07f)
          Met_var_IsAvailable(45)=.true.

        iwf25_scale_facs = 0.0_sp
        iwf25_offsets    = 0.0_sp
        iwf25_scale_facs(1)  = 1.0_sp    ; iwf25_offsets(1)  = 32066.0_sp   ! hgt
        iwf25_scale_facs(2)  = 0.01_sp   ; iwf25_offsets(2)  = 202.66_sp    ! uwnd
        iwf25_scale_facs(3)  = 0.01_sp   ; iwf25_offsets(3)  = 202.66_sp    ! vwnd
        iwf25_scale_facs(4)  = 0.001_sp  ; iwf25_offsets(4)  = 29.765_sp    ! omega
        iwf25_scale_facs(5)  = 0.01_sp   ; iwf25_offsets(5)  = 477.66_sp    ! air (temperature)
        iwf25_scale_facs(6)  = 1.0_sp    ; iwf25_offsets(6)  = 0.0_sp       ! level
        iwf25_scale_facs(20) = 10.0_sp   ; iwf25_offsets(20) = 327650.0_sp  ! pres (lcb)
        iwf25_scale_facs(21) = 10.0_sp   ; iwf25_offsets(21) = 327650.0_sp  ! pres (lct)
        iwf25_scale_facs(30) = 0.01_sp   ; iwf25_offsets(30) = 302.66_sp    ! rhum
        iwf25_scale_facs(31) = 1.0e-6_sp ; iwf25_offsets(31) = 0.032666_sp  ! shum
        iwf25_scale_facs(32) = 1.0e-6_sp ; iwf25_offsets(32) = 0.032666_sp  ! shum
        iwf25_scale_facs(44) = 1.0e-7_sp ; iwf25_offsets(44) = 0.0032765_sp ! prate
        iwf25_scale_facs(45) = 1.0e-7_sp ; iwf25_offsets(45) = 0.0031765_sp ! cprat

        fill_value_sp(MR_iwindformat) = -9999.0_sp

       elseif (MR_iwindformat.eq.26) then
         ! JRA-55 reanalysis 1.25 degree files 
         ! https://rda.ucar.edu/datasets/ds628.0/

        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "initial_time0_hours"       ! time
        Met_vardim_names(1) = "initial_time0_hours"       ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "lv_ISBL1"      ! pressure (17 levels 1000 -> 10)
        Met_vardim_names(2) = "lv_ISBL1"      ! pressure (17 levels 1000 -> 10)
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "g0_lat_2"        ! y        (90.0 -> -90.0)
        Met_vardim_names(3) = "g0_lat_2"        ! y        (90.0 -> -90.0)
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "g0_lat_2"        ! x        (0.0 -> 357.5)
        Met_vardim_names(4) = "g0_lat_2"        ! x        (0.0 -> 357.5)
          Met_dim_IsAvailable(4)=.true.
        !Met_dim_names(5) = "lv_ISBL1"      ! pressure coordinate for Vz (12 levels 1000 -> 100)
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = "lv_ISBL1"      ! pressure coordinate for RH (8 levels 1000 -> 300)
        !  Met_dim_IsAvailable(6)=.true.

        ! Momentum / State variables
        Met_var_names(1) = "HGT_GDS0_ISBL"        ! short m^2/s^2 (32066.f,1.f)
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "UGRD_GDS0_ISBL"       ! short m/s (202.66f,0.01f)
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "VGRD_GDS0_ISBL"       ! short m/s (202.66f,0.01f)
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "VVEL_GDS0_ISBL"      ! short Pa/s (29.765f,0.001f)
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "TMP_GDS0_ISBL"        ! short K (477.66f,0.01f)
          Met_var_IsAvailable(5)=.true.

        fill_value_sp(MR_iwindformat) = -9999.0_sp

       elseif (MR_iwindformat.eq.27) then
         ! NOAA-CIRES reanalysis 2.5 degree files 
         ! https://rda.ucar.edu/datasets/ds131.2/
        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "initial_time0_hours"       ! time
        Met_vardim_names(1) = "initial_time0_hours"       ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "lv_ISBL1"      ! pressure (24 levels 10 -> 1000)
        Met_vardim_names(2) = "lv_ISBL1"      ! pressure (24 levels 10 -> 1000)
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "g0_lat_2"      ! y        (90.0 -> -90.0)
        Met_vardim_names(3) = "g0_lat_2"      ! y        (90.0 -> -90.0)
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "g0_lon_3"      ! x        (0.0 -> 378.0)
        Met_vardim_names(4) = "g0_lon_3"      ! x        (0.0 -> 378.0)
          Met_dim_IsAvailable(4)=.true.
        !Met_dim_names(5) = "lv_ISBL1"      ! pressure coordinate for Vz (19 levels 100 -> 1000)
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = "lv_ISBL1"      ! pressure coordinate for RH (19 levels 100 -> 1000)
        !  Met_dim_IsAvailable(6)=.true.

        ! Momentum / State variables
        Met_var_names(1) = "HGT_GDS0_ISBL_10"        ! float m^2/s^2
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "U_GRD_GDS0_ISBL_10"      ! float m/s
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "V_GRD_GDS0_ISBL_10"      ! float m/s
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "V_VEL_GDS0_ISBL_10"      ! float Pa/s 
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "TMP_GDS0_ISBL_10"        ! float K
          Met_var_IsAvailable(5)=.true.
        ! Surface
        Met_var_names(10) = "HPBL"
          Met_var_IsAvailable(10)=.true.
        ! Atmospheric Structure
        Met_var_names(22) = "TMP"
          Met_var_IsAvailable(22)=.true.
        Met_var_names(23) = "TCDC"
          Met_var_IsAvailable(23)=.true.
        ! Moisture
        Met_var_names(30) = "R_H_GDS0_ISBL_10"     ! float
          Met_var_IsAvailable(30)=.true.
        ! Precipitation
        Met_var_names(40) = "CRAIN"
          Met_var_IsAvailable(40)=.true.
        Met_var_names(44) = "PRATE"
          Met_var_IsAvailable(44)=.true.
        Met_var_names(45) = "CPRAT"
          Met_var_IsAvailable(45)=.true.

        fill_value_sp(MR_iwindformat) = 1.e+20_sp

       elseif (MR_iwindformat.eq.28) then
         ! ECMWF Interim Reanalysis (ERA-Interim)
         ! https://rda.ucar.edu/datasets/ds627.0
        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "time"       ! time
        Met_vardim_names(1) = "time"       ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "isobaric"      ! pressure (37 levels 1000 -> 1)
        Met_vardim_names(2) = "isobaric"      ! pressure (37 levels 1000 -> 1)
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "lat"        ! y        (90.0 -> -90.0)
        Met_vardim_names(3) = "lat"        ! y        (90.0 -> -90.0)
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "lon"        ! x        (0.0 -> 357.5)
        Met_vardim_names(4) = "lon"        ! x        (0.0 -> 357.5)
          Met_dim_IsAvailable(4)=.true.
        !Met_dim_names(5) = "isobaric"      ! pressure coordinate for Vz (12 levels 1000 -> 1)
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = "isobaric"      ! pressure coordinate for RH (8 levels 1000 -> 1)
        !  Met_dim_IsAvailable(6)=.true.

        ! Momentum / State variables
        Met_var_names(1) = "Geopotential_isobaric"        ! m^2/s^2
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "U_component_of_wind_isobaric"       ! m/s
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "V_component_of_wind_isobaric"       ! m/s
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "Vertical_velocity_isobaric"      ! Pa/s
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "Temperature_isobaric"        ! K 
          Met_var_IsAvailable(5)=.true.
        ! Moisture
        Met_var_names(30) = "Relative_humidity_isobaric"       ! 
          Met_var_IsAvailable(30)=.true.
        Met_var_names(31) = "Specific_humidity_isobaric"      ! 
          Met_var_IsAvailable(31)=.true.

        fill_value_sp(MR_iwindformat) = -9999.0_sp ! actually NaNf
        Met_var_conversion_factor(1) = 1.0_sp/9.81_sp

       elseif (MR_iwindformat.eq.29) then
         ! ECMWF ERA5
         ! https://rda.ucar.edu/datasets/ds630.0
         ! Note: files are provided as one variable per file

        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "time"       ! time (provided in hours since 1990-1-1 00Z)
        Met_vardim_names(1) = "time"       ! time (provided in hours since 1990-1-1 00Z)
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "level"      ! pressure (37 levels 1000 -> 1)
        Met_vardim_names(2) = "level"      ! pressure (37 levels 1000 -> 1)
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "latitude"        ! y        (90.0 -> -90.0)
        Met_vardim_names(3) = "latitude"        ! y        (90.0 -> -90.0)
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "longitude"        ! x        (0.0 -> 357.5)
        Met_vardim_names(4) = "longitude"        ! x        (0.0 -> 357.5)
          Met_dim_IsAvailable(4)=.true.
        !Met_dim_names(5) = "level"      ! pressure coordinate for Vz (12 levels 1000 -> 1)
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = "level"      ! pressure coordinate for RH (8 levels 1000 -> 1)
        !  Met_dim_IsAvailable(6)=.true.
 
        !  Potential vorticity  e5.oper.an.pl.128_060_pv.regn320sc.2018062000_2018062023.nc
        !  Specific rain water content  e5.oper.an.pl.128_075_crwc.regn320sc.2018062000_2018062023.nc
        !  Secific snow water content  e5.oper.an.pl.128_076_cswc.regn320sc.2018062000_2018062023.nc
        !  Geopotential  e5.oper.an.pl.128_129_z.regn320sc.2018062000_2018062023.nc
        !  Temperature  e5.oper.an.pl.128_130_t.regn320sc.2018062000_2018062023.nc
        !  U component of wind  e5.oper.an.pl.128_131_u.regn320uv.2018062000_2018062023.nc
        !  V component of wind  e5.oper.an.pl.128_132_v.regn320uv.2018062000_2018062023.nc
        !  Specific humidity  e5.oper.an.pl.128_133_q.regn320sc.2018062000_2018062023.nc
        !  Vertical velocity  e5.oper.an.pl.128_135_w.regn320sc.2018062000_2018062023.nc
        !  Vorticity  e5.oper.an.pl.128_138_vo.regn320sc.2018062000_2018062023.nc
        !  Divergence  e5.oper.an.pl.128_155_d.regn320sc.2018062000_2018062023.nc
        !  Relative humidity  e5.oper.an.pl.128_157_r.regn320sc.2018062000_2018062023.nc
        !  Ozone nass mixing ratio e5.oper.an.pl.128_203_o3.regn320sc.2018062000_2018062023.nc
        !  Specific cloud liquid water content e5.oper.an.pl.128_246_clwc.regn320sc.2018062000_2018062023.nc
        !  Specific cloud ice water content e5.oper.an.pl.128_247_ciwc.regn320sc.2018062000_2018062023.nc
        !  Cloud cover  e5.oper.an.pl.128_248_cc.regn320sc.2018062000_2018062023.nc


       elseif (MR_iwindformat.eq.31) then
         ! Catania forecast

        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "frtime"       ! time
        Met_vardim_names(1) = "frtime"       ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "level"      ! pressure (17 levels 1000 -> 100)
        Met_vardim_names(2) = "level"      ! pressure (17 levels 1000 -> 100)
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "lat"      ! y        (34.5 -> -40.32)
        Met_vardim_names(3) = "lat"      ! y        (34.5 -> -40.32)
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "lon"      ! x        (12.5 -> 18.0)
        Met_vardim_names(4) = "lon"      ! x        (12.5 -> 18.0)
          Met_dim_IsAvailable(4)=.true.
        !Met_dim_names(5) = "level"      ! pressure coordinate for Vz 
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = "level"      ! pressure coordinate for RH 
        !  Met_dim_IsAvailable(6)=.true.

        ! Momentum / State variables
        Met_var_names(1) = "H"      ! float m
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "u"      ! float m/s
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "v"      ! float m/s
          Met_var_IsAvailable(3)=.true.
        Met_var_names(5) = "T"        ! float K
          Met_var_IsAvailable(5)=.true.

        fill_value_sp(MR_iwindformat) = -9999.0_sp

       elseif (MR_iwindformat.eq.32) then
         ! Air Force Weather Agency subcenter = 0
         ! GALWEM

!        Met_dim_IsAvailable=.false.
!        Met_var_IsAvailable=.false.
!
!        Met_dim_names(1) = "time"       ! time
!          Met_dim_IsAvailable(1)=.true. 
!        Met_dim_names(2) = "isobaric"       ! pressure (39 levels 1013 -> 0.05)
!          Met_dim_IsAvailable(2)=.true. 
!        Met_dim_names(3) = "lat"      ! y        (34.5 -> -40.32)
!          Met_dim_IsAvailable(3)=.true. 
!        Met_dim_names(4) = "lon"      ! x        (12.5 -> 18.0)
!          Met_dim_IsAvailable(4)=.true. 
!        Met_dim_names(5) = "isobaric1"      ! pressure coordinate for Vz 
!          Met_dim_IsAvailable(5)=.true. 
!        Met_dim_names(6) = "isobaric2"      ! pressure coordinate for RH 
!          Met_dim_IsAvailable(6)=.true. 
!
!        ! Momentum / State variables
!        Met_var_names(1) = "Geopotential_height_isobaric"      ! float m
!          Met_var_IsAvailable(1)=.true.
!        Met_var_names(2) = "u-component_of_wind_isobaric"      ! float m/s
!          Met_var_IsAvailable(2)=.true.
!        Met_var_names(3) = "v-component_of_wind_isobaric"      ! float m/s
!          Met_var_IsAvailable(3)=.true.
!        Met_var_names(4) = "Vertical_velocity_pressure_isobaric"       ! float Pa/s
!          Met_var_IsAvailable(4)=.true.
!        Met_var_names(5) = "Temperature_isobaric"        ! float K
!          Met_var_IsAvailable(5)=.true.
!        ! Surface
!        Met_var_names(11) = "u-component_of_wind_height_above_ground"
!          Met_var_IsAvailable(11)=.true.
!        Met_var_names(12) = "v-component_of_wind_height_above_ground"
!          Met_var_IsAvailable(12)=.true.
!        Met_var_names(15) = "Water_equivalent_of_accumulated_snow_depth_surface"
!          Met_var_IsAvailable(15)=.false. ! Need to convert from kg/m2 to m
!        Met_var_names(16) = "Column-integrated_soil_moisture_depth_below_surface"
!          Met_var_IsAvailable(16)=.false. ! Need to convert from kg/m2 to vol%
!        ! Moisture
!        Met_var_names(30) = "Relative_humidity_isobaric"      !        float 
!          Met_var_IsAvailable(30)=.true.
!        ! Precipitation
!        Met_var_names(44) = "Large_scale_precipitation_rate_surface" !kg/m2/s
!          Met_var_IsAvailable(44)=.true.
!        Met_var_names(45) = "Convective_precipitation_rate_surface" !kg/m2 or
!          Met_var_IsAvailable(45)=.true.
!
!        fill_value_sp(MR_iwindformat) = -9999._sp ! actually NaNf




        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "time"       ! time
        Met_vardim_names(1) = "time"       ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "isobaric"       ! pressure (39 levels 1013 -> 0.05)
        Met_vardim_names(2) = "isobaric"       ! pressure (39 levels 1013 -> 0.05)
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "lat"      ! y        (34.5 -> -40.32)
        Met_vardim_names(3) = "lat"      ! y        (34.5 -> -40.32)
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "lon"      ! x        (12.5 -> 18.0)
        Met_vardim_names(4) = "lon"      ! x        (12.5 -> 18.0)
          Met_dim_IsAvailable(4)=.true.
        !Met_dim_names(5) = "isobaric"      ! pressure coordinate for Vz 
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = "isobaric1"      ! pressure coordinate for RH 
        !  Met_dim_IsAvailable(6)=.true.

        ! Momentum / State variables
        Met_var_names(1) = "Geopotential_height_isobaric"      ! float m
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "u-component_of_wind_isobaric"      ! float m/s
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "v-component_of_wind_isobaric"      ! float m/s
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "Vertical_velocity_pressure_isobaric"       ! float Pa/s
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "Temperature_isobaric"        ! float K
          Met_var_IsAvailable(5)=.true.
        ! Surface
        Met_var_names(11) = "u-component_of_wind_height_above_ground"
          Met_var_IsAvailable(11)=.true.
        Met_var_names(12) = "v-component_of_wind_height_above_ground"
          Met_var_IsAvailable(12)=.true.
        Met_var_names(15) = "Water_equivalent_of_accumulated_snow_depth_surface"
          Met_var_IsAvailable(15)=.false. ! Need to convert from kg/m2 to m
        Met_var_names(16) = "Column-integrated_soil_moisture_depth_below_surface"
          Met_var_IsAvailable(16)=.false. ! Need to convert from kg/m2 to vol%
        ! Moisture
        Met_var_names(30) = "Relative_humidity_isobaric"      !        float 
          Met_var_IsAvailable(30)=.true.

        fill_value_sp(MR_iwindformat) = -9999._sp ! actually NaNf


       elseif (MR_iwindformat.eq.33) then
         ! CCSM3.0 Community Atmosphere Model (CAM)
         ! http://www.cesm.ucar.edu/models/atm-cam/
         ! peleoclimate monthly averages

        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "time"       ! time
        Met_vardim_names(1) = "time"       ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "lev"      ! pressure (26 levels ~1000 -> ~3.5)
        Met_vardim_names(2) = "lev"      ! pressure (26 levels ~1000 -> ~3.5)
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "lat"      ! y        (34.5 -> -40.32)
        Met_vardim_names(3) = "lat"      ! y        (34.5 -> -40.32)
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "lon"      ! x        (12.5 -> 18.0)
        Met_vardim_names(4) = "lon"      ! x        (12.5 -> 18.0)
          Met_dim_IsAvailable(4)=.true.
        !Met_dim_names(5) = "lev"      ! pressure coordinate for Vz 
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = "lev"      ! pressure coordinate for RH 
        !  Met_dim_IsAvailable(6)=.true.

        Met_dim_fac(1) = 24.0

        ! Momentum / State variables
        Met_var_names(1) = "Z3"      ! float m
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "U"      ! float m/s
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "V"      ! float m/s
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "OMEGA"    ! float Pa/s
          Met_var_IsAvailable(4)=.true. 
        Met_var_names(5) = "T"        ! float K
          Met_var_IsAvailable(5)=.true.

        Met_var_names(30) = "RELHUM"     ! float
          Met_var_IsAvailable(30)=.true.
        Met_var_names(31) = "Q"     ! float
          Met_var_IsAvailable(31)=.true.

        fill_value_sp(MR_iwindformat) = -9999.0_sp

       elseif (MR_iwindformat.eq.40) then
         ! NASA-GEOS Cp

        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "time"       ! time
        Met_vardim_names(1) = "time"       ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "lev"   ! pressure (1000 -> 1 hPa in 37 levels)
        Met_vardim_names(2) = "lev"   ! pressure (1000 -> 1 hPa in 37 levels)
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "lat"        ! y        (-90.0 -> 90.0) 361
        Met_vardim_names(3) = "lat"        ! y        (-90.0 -> 90.0) 361
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "lon"        ! x        (-180.0 -> 179.375) 576
        Met_vardim_names(4) = "lon"        ! x        (-180.0 -> 179.375) 576
          Met_dim_IsAvailable(4)=.true.
        !Met_dim_names(5) = "lev"   ! pressure coordinate for Vz
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = "lev"   ! pressure coordinate for RH
        !  Met_dim_IsAvailable(6)=.true.

        Met_dim_fac(1) = 1.0/60.0

        ! Momentum / State variables
        Met_var_names(1) = "H"           ! float m^2/s^2
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "U"           ! float m/s
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "V"           ! float m/s
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "OMEGA"       ! float Pa/s
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "T"           ! float K
          Met_var_IsAvailable(5)=.true.

        fill_value_sp(MR_iwindformat) = 1.0e15_sp

       elseif (MR_iwindformat.eq.41) then
         ! NASA-GEOS Np

        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "time"       ! time
        Met_vardim_names(1) = "time"       ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "lev"   ! pressure (1000 -> 0.1 hPa in 42 levels)
        Met_vardim_names(2) = "lev"   ! pressure (1000 -> 0.1 hPa in 42 levels)
          Met_dim_IsAvailable(2)=.true.      
        Met_dim_names(3) = "lat"        ! y        (-90.0 -> 90.0) 721 (0.25)
        Met_vardim_names(3) = "lat"        ! y        (-90.0 -> 90.0) 721 (0.25)
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "lon"        ! x        (-180.0 -> 179.6875) 1152 (0.31250)
        Met_vardim_names(4) = "lon"        ! x        (-180.0 -> 179.6875) 1152 (0.31250)
          Met_dim_IsAvailable(4)=.true.     
        !Met_dim_names(5) = "lev"   ! pressure coordinate for Vz
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = "lev"   ! pressure coordinate for RH
        !  Met_dim_IsAvailable(6)=.true.

        Met_dim_fac(1) = 1.0/60.0

        ! Momentum / State variables
        Met_var_names(1) = "H"           ! float m^2/s^2
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "U"           ! float m/s
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "V"           ! float m/s
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "OMEGA"       ! float Pa/s
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "T"           ! float K
          Met_var_IsAvailable(5)=.true.

        fill_value_sp(MR_iwindformat) = 1.0e15_sp

       elseif (MR_iwindformat.eq.50) then
         ! WRF - output

        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "Time"       ! time
        Met_vardim_names(1) = "Time"       ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "bottom_top"      ! pressure (24 levels 10 -> 1000)
        Met_vardim_names(2) = "bottom_top"      ! pressure (24 levels 10 -> 1000)
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "south_north"      ! y        (90.0 -> -90.0)
        Met_vardim_names(3) = "south_north"      ! y        (90.0 -> -90.0)
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "west_east"      ! x        (0.0 -> 378.0)
        Met_vardim_names(4) = "west_east"      ! x        (0.0 -> 378.0)
          Met_dim_IsAvailable(4)=.true.
        !Met_dim_names(5) = "bottom_top_stag"      ! pressure coordinate for Vz (19 levels 100 -> 1000)
        !  Met_dim_IsAvailable(5)=.true.
        !Met_dim_names(6) = ""      ! pressure coordinate for RH (19 levels 100 -> 1000)
        !  Met_dim_IsAvailable(6)=.false.

        ! for pressure, read "P"  :: perturbation pressure
        !               and  "PB" :: base pressure

        ! for geopotential, read "PH"  :: perturbation geopotential
        !                   and  "PHB" :: base-state geopotential

        ! Momentum / State variables
        Met_var_names(1) = "PHB"        ! float m^2/s^2
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "U"      ! float m/s
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "V"      ! float m/s
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "W"      ! float m/s
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "T"      ! float K perturbation potential temperature (theta-t0)
          Met_var_IsAvailable(5)=.true.
        Met_var_names(6) = "PB"
          Met_var_IsAvailable(6)=.true.

        ! Surface
        Met_var_names(10) = "PBLH"
          Met_var_IsAvailable(10)=.true.
        Met_var_names(11) = "U10"
          Met_var_IsAvailable(11)=.true.
          Met_var_ndim(11)=3
        Met_var_names(12) = "V10"
          Met_var_IsAvailable(12)=.true.
          Met_var_ndim(12)=3

        Met_var_names(13) = "UST"
          Met_var_IsAvailable(13)=.true.
        Met_var_names(15) = "SNOWH"
          Met_var_IsAvailable(15)=.true.

        Met_var_names(16) = "SMOIS" !Soil moisture m3 m-3
          Met_var_IsAvailable(16)=.true.
        ! Moisture
        Met_var_names(31) = "QVAPOR" !QV (specific humidity)
          Met_var_IsAvailable(31)=.true.
        ! Precipitation
        Met_var_names(44) = "RAINC"   ! ACCUMULATED TOTAL CUMULUS PRECIPITATION in mm
          Met_var_IsAvailable(44)=.true.
        Met_var_names(45) = "RAINNC"  ! ACCUMULATED TOTAL GRID SCALE PRECIPITATION in mm
          Met_var_IsAvailable(45)=.true.

        fill_value_sp(MR_iwindformat) = 1.e+20_sp

        Met_var_conversion_factor(1) = 1.0_sp/9.81_sp

      elseif(MR_iwindformat.eq.51)then
          ! NAM 198 5.953 km AK

        Met_dim_IsAvailable=.false.
        Met_var_IsAvailable=.false.

        Met_dim_names(1) = "time1"      ! time
          Met_dim_IsAvailable(1)=.true.
        Met_dim_names(2) = "isobaric"  ! pressure
          Met_dim_IsAvailable(2)=.true.
        Met_dim_names(3) = "y"         ! y
          Met_dim_IsAvailable(3)=.true.
        Met_dim_names(4) = "x"         ! x
          Met_dim_IsAvailable(4)=.true.
        Met_dim_names(5) = "isobaric"  ! pressure coordinate for Vz
          Met_dim_IsAvailable(5)=.true.
        Met_dim_names(6) = "isobaric" ! pressure coordinate for RH
          Met_dim_IsAvailable(6)=.true.

        ! Mechanical / State variables
        Met_var_names(1) = "Geopotential_height_isobaric"    !        float 
          Met_var_IsAvailable(1)=.true.
        Met_var_names(2) = "u-component_of_wind_isobaric"    !        float 
          Met_var_IsAvailable(2)=.true.
        Met_var_names(3) = "v-component_of_wind_isobaric"    !        float 
          Met_var_IsAvailable(3)=.true.
        Met_var_names(4) = "Vertical_velocity_pressure_isobaric"  ! float
          Met_var_IsAvailable(4)=.true.
        Met_var_names(5) = "Temperature_isobaric"            !        float 
          Met_var_IsAvailable(5)=.true.
        ! Surface
        Met_var_names(10) = "Planetary_boundary_layer_height_surface"
          Met_var_IsAvailable(10)=.true.
        Met_var_names(11) = "u-component_of_wind_height_above_ground"
          Met_var_IsAvailable(11)=.true.
        Met_var_names(12) = "v-component_of_wind_height_above_ground"
          Met_var_IsAvailable(12)=.true.
        Met_var_names(15) = "Snow_depth_surface"
          Met_var_IsAvailable(15)=.true.
        Met_var_names(23) = "Total_cloud_cover_entire_atmosphere"
          Met_var_IsAvailable(23)=.true.
        ! Moisture
        Met_var_names(30) = "Relative_humidity_isobaric"      !        float 
          Met_var_IsAvailable(30)=.true.
        Met_var_names(31) = "Specific_humidity_isobaric"
          Met_var_IsAvailable(31)=.true.

        fill_value_sp(MR_iwindformat) = -9999._sp ! actually NaNf

      else
        ! Not a recognized MR_iwindformat
        ! call reading of template windfile variable names
        write(MR_global_info,*)"windfile format not recognized."
        stop 1
      endif

      if(Met_var_IsAvailable(4)) Have_Vz = .true.

      if(.not.MR_iwindformat.eq.50)then
        !---------------------------------------------------------------------------------
        ! Checking for dimension length and values for x,y,t,p
        !   Assume all files have the same format
        maxdimlen = 0
        nSTAT=nf90_open(adjustl(trim(MR_windfiles(1))),NF90_NOWRITE, ncid)
        if(nSTAT.ne.NF90_NOERR) then
          write(MR_global_error,*)'MR ERROR: open NC file: ',nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: open NC file: ',nf90_strerror(nSTAT)
          write(MR_global_error,*)'Exiting'
          stop 1
        endif
        do ivar = 1,MR_MAXVARS
          if (.not.Met_var_IsAvailable(ivar)) cycle  ! Only look at variables that are available
          if (Met_var_ndim(ivar).ne.4) cycle         !  and only ones with a 'level' dimension
          invar = Met_var_names(ivar)
          nSTAT = nf90_inq_varid(ncid,invar,in_var_id)  ! get the var_id for this named variable
          if(nSTAT.ne.NF90_NOERR)then
            write(MR_global_error,*)'MR WARNING: inq_varid: ',invar,nf90_strerror(nSTAT)
            write(MR_global_error,*)'  Cannot find variable ',invar
            write(MR_global_error,*)'  Setting Met_var_IsAvailable to .false.'
            write(MR_global_log  ,*)'MR WARNING: inq_varid: ',invar,nf90_strerror(nSTAT)
            Met_var_IsAvailable(ivar) = .false.
            cycle
          endif
          nSTAT = nf90_inquire_variable(ncid, in_var_id, invar, &
                    xtype = var_xtype, &
                    ndims = var_ndims)   ! get the number of dimensions
          if(nSTAT.ne.NF90_NOERR)then
            write(MR_global_error,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
            write(MR_global_log  ,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
            stop 1
          endif
          if (var_ndims.ne.Met_var_ndim(ivar))then
            write(MR_global_error,*)'MR ERROR: The actual number of dimensions differs from'
            write(MR_global_error,*)'          what is expected'
            write(MR_global_error,*)'      Variable : ',ivar,Met_var_names(ivar)
            write(MR_global_error,*)'      Expected : ',Met_var_ndim(ivar)
            write(MR_global_error,*)'      Found    : ',var_ndims
            stop 1
          endif
          allocate(var_dimIDs(var_ndims))
          nSTAT = nf90_inquire_variable(ncid, in_var_id, invar, &
                    dimids = var_dimIDs(:var_ndims))
          if(nSTAT.ne.NF90_NOERR)then
            write(MR_global_error,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
            write(MR_global_log  ,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
            stop 1
          endif
    
          ! 3-d trasient variables should be in the COORDS convention (time, level, y, x)
          ! if ivar = 1 (Geopotential Height), then get the info on x,y and t too
          if(ivar.eq.1)then
            i_dim = 1  ! get x info
            nSTAT = nf90_inquire_dimension(ncid,var_dimIDs(i_dim), &
                         name =  dimname, &
                         len = dimlen)
            if(nSTAT.ne.NF90_NOERR)then
              write(MR_global_error,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
              write(MR_global_log  ,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
              stop 1
            endif
            if(index(dimname,Met_dim_names(4)).ne.0)then
              nx_fullmet = dimlen
              xdim_id    = var_dimIDs(i_dim)
            endif
            !nSTAT = nf90_inq_varid(ncid,dimname,var_id) ! get the variable associated with this dim
            !if(nSTAT.ne.NF90_NOERR)then
            !  write(MR_global_error,*)'MR ERROR: inq_varid ',dimname,nf90_strerror(nSTAT)
            !  write(MR_global_log  ,*)'MR ERROR: inq_varid ',dimname,nf90_strerror(nSTAT)
            !  stop 1
            !endif
            !! Check if we need to read into a float or a double
            !nSTAT = nf90_inquire_variable(ncid, var_id, dimname, xtype = var_xtype)
            !if(nSTAT.ne.NF90_NOERR)then
            !  write(MR_global_error,*)'MR ERROR: inq_variable: ',dimname,nf90_strerror(nSTAT)
            !  write(MR_global_log  ,*)'MR ERROR: inq_variable: ',dimname,nf90_strerror(nSTAT)
            !  stop 1
            !endif
            !allocate(x_fullmet_sp(0:nx_fullmet+1))
            !if(var_xtype.eq.NF90_FLOAT)then
            !  allocate(dum1d_sp(dimlen))
            !  nSTAT = nf90_get_var(ncid,var_id,dum1d_sp, &
            !         start = (/1/),count = (/dimlen/))
            !  if(nSTAT.ne.NF90_NOERR)then
            !    write(MR_global_error,*)'MR ERROR: get_var ',dimname,nf90_strerror(nSTAT)
            !    write(MR_global_log  ,*)'MR ERROR: get_var ',dimname,nf90_strerror(nSTAT)
            !    stop 1
            !  endif
            !  ! copy to local variable
            !  x_fullmet_sp(1:nx_fullmet) = dum1d_sp(1:nx_fullmet)
            !  deallocate(dum1d_sp)
            !elseif(var_xtype.eq.NF90_DOUBLE)then
            !  allocate(dum1d_dp(dimlen))
            !  nSTAT = nf90_get_var(ncid,var_id,dum1d_dp, &
            !         start = (/1/),count = (/dimlen/))
            !  if(nSTAT.ne.NF90_NOERR)then
            !    write(MR_global_error,*)'MR ERROR: get_var ',dimname,nf90_strerror(nSTAT)
            !    write(MR_global_log  ,*)'MR ERROR: get_var ',dimname,nf90_strerror(nSTAT)
            !    stop 1
            !  endif
            !  ! copy to local variable
            !  x_fullmet_sp(1:nx_fullmet) = real(dum1d_dp(1:nx_fullmet),kind=sp)
            !  deallocate(dum1d_dp)
            !else
            !  write(MR_global_error,*)'MR ERROR: Cannot recognize variable type for x'
            !  stop 5
            !endif
            !! Check the units
            !nSTAT = nf90_Inquire_Attribute(ncid, var_id,&
            !                               "units",xtype, length, attnum)
            !if(nSTAT.ne.NF90_NOERR)then
            !  write(MR_global_error,*)'MR WARNING: cannot file units ',dimname,nf90_strerror(nSTAT)
            !  write(MR_global_log  ,*)'MR WARNING: cannot file units ',dimname,nf90_strerror(nSTAT)
            !else
            !  nSTAT = nf90_get_att(ncid, var_id,"units",ustring)
            !  if(nSTAT.ne.NF90_NOERR) then
            !    write(MR_global_error,*)'MR ERROR: get_att:',"time",nf90_strerror(nSTAT)
            !    write(MR_global_log  ,*)'MR ERROR: get_att:',"time",nf90_strerror(nSTAT)
            !    stop 1
            !  endif
            !  if(index(ustring,'km').gt.0.or.&
            !     index(ustring,'kilo').gt.0)then
            !    ! This is a projected grid
            !    IsLatLon_MetGrid  = .false.
            !  elseif(index(ustring,'deg').gt.0)then
            !    ! This is a lon/lat grid
            !    IsLatLon_MetGrid  = .true.
            !  else
            !    write(MR_global_error,*)"MR ERROR: Cannot determine if the grid is lon/lat or projected"
            !    stop 5
            !  endif
            !endif
            !! Finally, check for orientation
            !if(x_fullmet_sp(1).lt.x_fullmet_sp(2))then
            !  x_inverted = .true.
            !else
            !  x_inverted = .false.
            !endif
  
            i_dim = 2  ! get y info
            nSTAT = nf90_inquire_dimension(ncid,var_dimIDs(i_dim), &
                         name =  dimname, &
                         len = dimlen)
            if(nSTAT.ne.NF90_NOERR)then
              write(MR_global_error,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
              write(MR_global_log  ,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
              stop 1
            endif
            if(index(dimname,Met_dim_names(3)).ne.0)then
              ny_fullmet = dimlen
              ydim_id    = var_dimIDs(i_dim)
            endif
  
            i_dim = 4  ! get t info
            nSTAT = nf90_inquire_dimension(ncid,var_dimIDs(i_dim), &
                         name =  dimname, &
                         len = dimlen)
            if(nSTAT.ne.NF90_NOERR)then
              write(MR_global_error,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
              write(MR_global_log  ,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
              stop 1
            endif
            if(index(dimname,Met_dim_names(1)).ne.0)then
              nt_fullmet = dimlen
              tdim_id    = var_dimIDs(i_dim)
            endif
  
          endif
          ! Now checking level coordinates (pressure, height, depth); third dimension
          i_dim = 3
          nSTAT = nf90_inquire_dimension(ncid,var_dimIDs(i_dim), &
                       name =  dimname, & 
                       len = dimlen)
          if(nSTAT.ne.NF90_NOERR)then
            write(MR_global_error,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
            write(MR_global_log  ,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
            stop 1
          endif
          if(index(dimname,'lev').ne.0.or.&
             index(dimname,'isobaric').ne.0.or.&
             index(dimname,'pressure').ne.0.or.&
             index(dimname,'height').ne.0.or.&
             index(dimname,'depth').ne.0.or.&
             index(dimname,'lv_ISBL1').ne.0.or.&
             index(dimname,'bottom_top').ne.0.or.&
             index(dimname,'bottom_top_stag').ne.0.or.&
             index(dimname,'soil_layers_stag').ne.0)then
            ! Log this level coordinate if it is the first
            if (nlev_coords_detected.eq.0)then
              nlev_coords_detected = nlev_coords_detected + 1
              Met_var_zdim_idx(ivar)  = nlev_coords_detected
              Met_var_zdim_ncid(ivar) = var_dimIDs(i_dim)
              maxdimlen = dimlen
            else
              ! Otherwise, check if this level coordinate has already been logged
              FoundOldDim = .false.
              do iivar = 1,ivar-1
                if (Met_var_zdim_ncid(iivar).eq.var_dimIDs(i_dim))then
                  FoundOldDim = .true.
                  Met_var_zdim_idx(ivar)  = Met_var_zdim_idx(iivar)
                  Met_var_zdim_ncid(ivar) = var_dimIDs(i_dim)
                  exit
                endif
              enddo
              if(.not.FoundOldDim)then
                nlev_coords_detected = nlev_coords_detected + 1
                Met_var_zdim_idx(ivar)  = nlev_coords_detected
                Met_var_zdim_ncid(ivar) = var_dimIDs(i_dim)
                if (maxdimlen.lt.dimlen) maxdimlen = dimlen
              endif
            endif
          else
            write(MR_global_error,*)'MR ERROR: level coordinate is not in pos. 3 for ',invar
            write(MR_global_log  ,*)'MR ERROR: level coordinate is not in pos. 3 for ',invar
            stop 1
          endif
          ! tidy up
          deallocate(var_dimIDs)
        enddo ! ivar
  
        ! We have all the level dimension names and dim_ids; now we need to get the sizes
        allocate(nlevs_fullmet(nlev_coords_detected))
        allocate(levs_code(nlev_coords_detected))
        allocate(levs_fullmet_sp(nlev_coords_detected,maxdimlen))
        do ivar = 1,MR_MAXVARS
          ! Check if this variable has a z-dimension (pressure, height, depth, etc.)
          if(Met_var_zdim_ncid(ivar).gt.0)then
            ! log the length of the dimension for this level coordinat
            nSTAT = nf90_inquire_dimension(ncid,Met_var_zdim_ncid(ivar), &
                       name =  dimname, &
                       len = dimlen)
            idx = Met_var_zdim_idx(ivar)
            nlevs_fullmet(idx) = dimlen
            ! Now inquire and populate the dimension variable info
            nSTAT = nf90_inq_varid(ncid,dimname,var_id)
            if(nSTAT.ne.NF90_NOERR)then
              write(MR_global_error,*)'MR ERROR: inq_varid ',dimname,nf90_strerror(nSTAT)
              write(MR_global_log  ,*)'MR ERROR: inq_varid ',dimname,nf90_strerror(nSTAT)
              stop 1
            endif
            ! Check if we need to read into a float or a double
            nSTAT = nf90_inquire_variable(ncid, var_id, dimname, xtype = var_xtype)
            if(nSTAT.ne.NF90_NOERR)then
              write(MR_global_error,*)'MR ERROR: inq_variable: ',dimname,nf90_strerror(nSTAT)
              write(MR_global_log  ,*)'MR ERROR: inq_variable: ',dimname,nf90_strerror(nSTAT)
              stop 1
            endif
            if(var_xtype.eq.NF90_FLOAT)then
              allocate(dum1d_sp(dimlen))
              nSTAT = nf90_get_var(ncid,var_id,dum1d_sp, &
                     start = (/1/),count = (/dimlen/))
              if(nSTAT.ne.NF90_NOERR)then
                write(MR_global_error,*)'MR ERROR: get_var ',dimname,nf90_strerror(nSTAT)
                write(MR_global_log  ,*)'MR ERROR: get_var ',dimname,nf90_strerror(nSTAT)
                stop 1
              endif
              ! copy to local variable
              levs_fullmet_sp(idx,1:nlevs_fullmet(idx)) = dum1d_sp(1:nlevs_fullmet(idx))
              deallocate(dum1d_sp)
            elseif(var_xtype.eq.NF90_DOUBLE)then
              allocate(dum1d_dp(dimlen))
              nSTAT = nf90_get_var(ncid,var_id,dum1d_dp, &
                     start = (/1/),count = (/dimlen/))
              if(nSTAT.ne.NF90_NOERR)then
                write(MR_global_error,*)'MR ERROR: get_var ',dimname,nf90_strerror(nSTAT)
                write(MR_global_log  ,*)'MR ERROR: get_var ',dimname,nf90_strerror(nSTAT)
                stop 1
              endif
              ! copy to local variable
              levs_fullmet_sp(idx,1:nlevs_fullmet(idx)) = real(dum1d_dp(1:nlevs_fullmet(idx)),kind=sp)
              deallocate(dum1d_dp)
            endif
            ! Check the units
            nSTAT = nf90_Inquire_Attribute(ncid, var_id,&
                                           "units",xtype, length, attnum)
            if(nSTAT.ne.NF90_NOERR)then
              write(MR_global_error,*)'MR WARNING: cannot find dim units ',dimname,nf90_strerror(nSTAT)
              write(MR_global_log  ,*)'MR WARNING: cannot find dim units ',dimname,nf90_strerror(nSTAT)
              IsPressureDimension = .false.
              stop 1
            else
              nSTAT = nf90_get_att(ncid, var_id,"units",ustring)
              if(nSTAT.ne.NF90_NOERR) then
                write(MR_global_error,*)'MR ERROR: get_att:',"time",nf90_strerror(nSTAT)
                write(MR_global_log  ,*)'MR ERROR: get_att:',"time",nf90_strerror(nSTAT)
                stop 1
              endif
              ! Note: the variables below are single-valued, not arrays on ivar
              !       If a pressure is found, the assumption here is that all pressure coordinates will
              !       be given in the same units (hPa or Pa) and the same orientations (bot to top, or
              !       inverted.
              if(index(ustring,'Pa').gt.0.or.&
                 index(ustring,'millibar').gt.0)then
                ! This is a pressure level
                IsPressureDimension = .true.
                if(index(ustring,'hPa').gt.0.or.&
                   index(ustring,'millibar').gt.0)then
                  Pressure_Conv_Fac = 100.0_sp
                else
                  Pressure_Conv_Fac = 1.0_sp
                endif
              else
                IsPressureDimension = .false.
              endif
            endif
            
            ! Finally, check for orientation
            if(IsPressureDimension)then
              if(levs_fullmet_sp(idx,1).lt.levs_fullmet_sp(idx,2))then
                z_inverted = .true.
              else
                z_inverted = .false.
              endif
            endif
          endif
        enddo  ! ivar
        ! Close file
        nSTAT = nf90_close(ncid)
        if(nSTAT.ne.NF90_NOERR)then
           write(MR_global_error,*)'MR ERROR: close file: ',nf90_strerror(nSTAT)
           write(MR_global_log  ,*)'MR ERROR: close file: ',nf90_strerror(nSTAT)
           stop 1
        endif
  
        write(MR_global_production,*)" Found these levels"
        write(MR_global_production,*)"  VaribleID    LevelIdx       dimID"
        do ivar = 1,MR_MAXVARS
          if (Met_var_IsAvailable(ivar)) &
              write(MR_global_production,*)ivar,Met_var_zdim_idx(ivar),Met_var_zdim_ncid(ivar)
        enddo
        ! Now invert if necessary and convert to Pa
        allocate(p_fullmet_sp(maxdimlen))
        do idx = 1,nlev_coords_detected
          if(z_inverted)then
            do i = 1,nlevs_fullmet(idx)
              p_fullmet_sp(nlevs_fullmet(idx)+1-i) = levs_fullmet_sp(idx,i)*Pressure_Conv_Fac
            enddo
          else
            p_fullmet_sp(1:nlevs_fullmet(idx)) = levs_fullmet_sp(idx,1:nlevs_fullmet(idx))*Pressure_Conv_Fac
          endif
          levs_fullmet_sp(idx,:) = 0.0_sp
          levs_fullmet_sp(idx,1:nlevs_fullmet(idx)) = p_fullmet_sp(1:nlevs_fullmet(idx))
        enddo
        deallocate(p_fullmet_sp)
  
        levs_code(1:nlev_coords_detected) = 0
        levs_code(1) = 1                       ! The first var checked (GPH) should have a one-to-one mapping
        ! Check how each of the pressure coordinates map onto the GPH grid
        if (nlev_coords_detected.gt.1)then
          ! Only bother if there are multiple perssure coordinates
          do idx = 2,nlev_coords_detected
            if (nlevs_fullmet(idx).gt.nlevs_fullmet(1))then
              ! This coordinate has more values than the GPH pressure coordinate
              levs_code(idx) = 4
            elseif (nlevs_fullmet(idx).lt.nlevs_fullmet(1))then
              ! It there are fewer levels, check if this is a truncated coordiante (code = 2)
              ! or one with missing levels that requires interpolation (code = 3)
              IsTruncatedDim = .true.
              do i=1,nlevs_fullmet(idx)
                if(abs(levs_fullmet_sp(idx,i)-levs_fullmet_sp(1,i)).gt.MR_EPS_SMALL)then
                  IsTruncatedDim = .false.
                  exit
                endif
              enddo
              if(IsTruncatedDim)then
                levs_code(idx) = 2
              else
                levs_code(idx) = 3
              endif
            else
              ! This coordinate has the same dimension as the GPH pressure coordinate.
              ! They are probably the same
              levs_code(idx) = 1
            endif
          enddo
        endif
  
  
        ! Now assign these levels to the working arrays
        np_fullmet    = nlevs_fullmet(Met_var_zdim_idx(1))  ! Assign fullmet the length of H,U,V
        !np_fullmet_Vz = np_fullmet  ! Initialize everything to the same pressure coordinate
        !np_fullmet_T  = np_fullmet
        !np_fullmet_RH = np_fullmet
        np_fullmet_P0 = 1
  
        !if(Met_var_IsAvailable(4)) &
        !  np_fullmet_Vz = nlevs_fullmet(Met_var_zdim_idx(4))  ! omega
        !if(Met_var_IsAvailable(5)) &
        !  np_fullmet_T  = nlevs_fullmet(Met_var_zdim_idx(5))  ! temperature
        !if(Met_var_IsAvailable(30)) &
        !  np_fullmet_RH = nlevs_fullmet(Met_var_zdim_idx(30)) ! Rel.Hum.
        if(Met_var_IsAvailable(44)) &
          np_fullmet_P0 = 1   ! Precip is 2d
  
        ! Geopotential
        allocate(p_fullmet_sp(np_fullmet))
        idx = Met_var_zdim_idx(1)
        p_fullmet_sp(1:nlevs_fullmet(idx)) = levs_fullmet_sp(idx,1:nlevs_fullmet(idx))
        ! Vertical velocity
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !idx = Met_var_zdim_idx(4)
        !p_fullmet_Vz_sp(1:np_fullmet_Vz) = p_fullmet_sp(1:np_fullmet_Vz)
        ! Temperature
        !allocate(p_fullmet_T_sp(np_fullmet_T))
        !idx = Met_var_zdim_idx(5)
        !p_fullmet_T_sp(1:np_fullmet_T) = p_fullmet_sp(1:np_fullmet_T)
        ! Rel.Hum
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !idx = Met_var_zdim_idx(30)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = p_fullmet_sp(1:np_fullmet_RH)
  
  
        MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet)/100.0_sp)
  
        x_inverted = .false. ! This is pretty much never true
        y_inverted = .false. ! This will be changed as needed below
      endif ! MR_iwindformat.eq.50
      !stop 5
      !---------------------------------------------------------------------------------


      if(MR_iwindformat.eq.0)then
        ! Template windfile (example for nam198)
        !  Need to populate
        call MR_Set_Met_Dims_Template_netcdf

      elseif(MR_iwindformat.eq.2)then
        write(MR_global_info,*)"MR_iwindformat = 2: should not be here."
        stop 1
      elseif(MR_iwindformat.eq.3)then
          ! 3 = NARR3D NAM221 32 km North America files
        call MR_Set_Met_NCEPGeoGrid(1221) ! This is almost NAM221, but uses a diff Re
        isGridRelative = .false.

        nt_fullmet = 1
        !np_fullmet = 29
        !np_fullmet_Vz = 29  ! omega
        !np_fullmet_RH = 29  ! rhum
        !np_fullmet_P0 = 1   ! Precip is 2d
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     875.0_sp, 850.0_sp, 825.0_sp, 800.0_sp, 775.0_sp, &
        !     750.0_sp, 725.0_sp, 700.0_sp, 650.0_sp, 600.0_sp, &
        !     550.0_sp, 500.0_sp, 450.0_sp, 400.0_sp, 350.0_sp, &
        !     300.0_sp, 275.0_sp, 250.0_sp, 225.0_sp, 200.0_sp, &
        !     175.0_sp, 150.0_sp, 125.0_sp, 100.0_sp /)
        !p_fullmet_Vz_sp(1:np_fullmet_Vz) = p_fullmet_sp(1:np_fullmet)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = p_fullmet_sp(1:np_fullmet)
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet))
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        !y_inverted = .false.
        !z_inverted = .true.

      elseif(MR_iwindformat.eq.4)then
          ! 4 = NAM Regional North America 221 (32 km)
        call MR_Set_Met_NCEPGeoGrid(221) 
        isGridRelative = .true.

        nt_fullmet = 1
        !np_fullmet = 42
        !np_fullmet_Vz = 42  ! omega
        !np_fullmet_RH = 42  ! rhum
        !np_fullmet_P0 = 1   ! Precip is 2d
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     875.0_sp, 850.0_sp, 825.0_sp, 800.0_sp, 775.0_sp, &
        !     750.0_sp, 725.0_sp, 700.0_sp, 675.0_sp, 650.0_sp, &
        !     625.0_sp, 600.0_sp, 575.0_sp, 550.0_sp, 525.0_sp, &
        !     500.0_sp, 475.0_sp, 450.0_sp, 425.0_sp, 400.0_sp, &
        !     375.0_sp, 350.0_sp, 325.0_sp, 300.0_sp, 275.0_sp, &
        !     250.0_sp, 225.0_sp, 200.0_sp, 175.0_sp, 150.0_sp, &
        !     125.0_sp, 100.0_sp,  75.0_sp,  50.0_sp,  30.0_sp, &
        !      20.0_sp,  10.0_sp /)
        !p_fullmet_Vz_sp(1:np_fullmet_Vz) = p_fullmet_sp(1:np_fullmet)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = p_fullmet_sp(1:np_fullmet)
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet))
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        !y_inverted = .false.
        !z_inverted = .true.

      elseif(MR_iwindformat.eq.5)then
        ! NAM 45-km Polar Sterographic
        call MR_Set_Met_NCEPGeoGrid(216)

        nt_fullmet = 29
        !np_fullmet = 42
        !np_fullmet_Vz = 39 ! omega
        !np_fullmet_RH = 42  ! rhum

        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     875.0_sp, 850.0_sp, 825.0_sp, 800.0_sp, 775.0_sp, &
        !     750.0_sp, 725.0_sp, 700.0_sp, 675.0_sp, 650.0_sp, &
        !     625.0_sp, 600.0_sp, 575.0_sp, 550.0_sp, 525.0_sp, &
        !     500.0_sp, 475.0_sp, 450.0_sp, 425.0_sp, 400.0_sp, &
        !     375.0_sp, 350.0_sp, 325.0_sp, 300.0_sp, 275.0_sp, &
        !     250.0_sp, 225.0_sp, 200.0_sp, 175.0_sp, 150.0_sp, &
        !     125.0_sp, 100.0_sp,  75.0_sp,  50.0_sp,  30.0_sp, &
        !      20.0_sp,  10.0_sp /)
        !p_fullmet_Vz_sp(1:np_fullmet_Vz) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     875.0_sp, 850.0_sp, 825.0_sp, 800.0_sp, 775.0_sp, &
        !     750.0_sp, 725.0_sp, 700.0_sp, 675.0_sp, 650.0_sp, &
        !     625.0_sp, 600.0_sp, 575.0_sp, 550.0_sp, 525.0_sp, &
        !     500.0_sp, 475.0_sp, 450.0_sp, 425.0_sp, 400.0_sp, &
        !     375.0_sp, 350.0_sp, 325.0_sp, 300.0_sp, 275.0_sp, &
        !     250.0_sp, 225.0_sp, 200.0_sp, 175.0_sp, 150.0_sp, &
        !     125.0_sp, 100.0_sp,  75.0_sp,  50.0_sp /)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     875.0_sp, 850.0_sp, 825.0_sp, 800.0_sp, 775.0_sp, &
        !     750.0_sp, 725.0_sp, 700.0_sp, 675.0_sp, 650.0_sp, &
        !     625.0_sp, 600.0_sp, 575.0_sp, 550.0_sp, 525.0_sp, &
        !     500.0_sp, 475.0_sp, 450.0_sp, 425.0_sp, 400.0_sp, &
        !     375.0_sp, 350.0_sp, 325.0_sp, 300.0_sp, 275.0_sp, &
        !     250.0_sp, 225.0_sp, 200.0_sp, 175.0_sp, 150.0_sp, & 
        !     125.0_sp, 100.0_sp,  75.0_sp,  50.0_sp /)
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet))
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        !y_inverted = .false.
        !z_inverted = .true.
      elseif(MR_iwindformat.eq.6)then
          ! 104 converted automatically from grib2
          ! NAM 90-km Polar Sterographic
        call MR_Set_Met_NCEPGeoGrid(104)

        nt_fullmet = 29
        !np_fullmet = 39
        !np_fullmet_Vz = 39 ! omega
        !np_fullmet_RH = 19  ! rhum
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     875.0_sp, 850.0_sp, 825.0_sp, 800.0_sp, 775.0_sp, &
        !     750.0_sp, 725.0_sp, 700.0_sp, 675.0_sp, 650.0_sp, &
        !     625.0_sp, 600.0_sp, 575.0_sp, 550.0_sp, 525.0_sp, &
        !     500.0_sp, 475.0_sp, 450.0_sp, 425.0_sp, 400.0_sp, &
        !     375.0_sp, 350.0_sp, 325.0_sp, 300.0_sp, 275.0_sp, &
        !     250.0_sp, 225.0_sp, 200.0_sp, 175.0_sp, 150.0_sp, &
        !     125.0_sp, 100.0_sp,  75.0_sp,  50.0_sp /)
        !p_fullmet_Vz_sp(1:np_fullmet_Vz) = p_fullmet_sp(1:np_fullmet)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = &
        !  (/1000.0_sp, 950.0_sp, 900.0_sp, 850.0_sp, 800.0_sp, &
        !     750.0_sp, 700.0_sp, 650.0_sp, 600.0_sp, 550.0_sp, &
        !     500.0_sp, 450.0_sp, 400.0_sp, 350.0_sp, 300.0_sp, &
        !     250.0_sp, 200.0_sp, 150.0_sp, 100.0_sp /)
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet)) 
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        !y_inverted = .false.
        !z_inverted = .true.
      elseif(MR_iwindformat.eq.7)then
          ! 212 converted automatically from grib2
          ! CONUS 40-km Lambert Conformal
        call MR_Set_Met_NCEPGeoGrid(212)

        nt_fullmet = 29
        !np_fullmet = 39
        !np_fullmet_Vz = 39 ! omega
        !np_fullmet_RH = 39  ! rhum
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))

        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     875.0_sp, 850.0_sp, 825.0_sp, 800.0_sp, 775.0_sp, &
        !     750.0_sp, 725.0_sp, 700.0_sp, 675.0_sp, 650.0_sp, &
        !     625.0_sp, 600.0_sp, 575.0_sp, 550.0_sp, 525.0_sp, &
        !     500.0_sp, 475.0_sp, 450.0_sp, 425.0_sp, 400.0_sp, &
        !     375.0_sp, 350.0_sp, 325.0_sp, 300.0_sp, 275.0_sp, &
        !     250.0_sp, 225.0_sp, 200.0_sp, 175.0_sp, 150.0_sp, &
        !     125.0_sp, 100.0_sp,  75.0_sp,  50.0_sp /)
        !p_fullmet_Vz_sp(1:np_fullmet_Vz) = p_fullmet_sp(1:np_fullmet)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     875.0_sp, 850.0_sp, 825.0_sp, 800.0_sp, 775.0_sp, &
        !     750.0_sp, 725.0_sp, 700.0_sp, 675.0_sp, 650.0_sp, &
        !     625.0_sp, 600.0_sp, 575.0_sp, 550.0_sp, 525.0_sp, &
        !     500.0_sp, 475.0_sp, 450.0_sp, 425.0_sp, 400.0_sp, &
        !     375.0_sp, 350.0_sp, 325.0_sp, 300.0_sp, 275.0_sp, &
        !     250.0_sp, 225.0_sp, 200.0_sp, 175.0_sp, 150.0_sp, &
        !     125.0_sp, 100.0_sp,  75.0_sp,  50.0_sp /)
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet)) 
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        !y_inverted = .false.
        !z_inverted = .true.

      elseif(MR_iwindformat.eq.8)then
          !  12 KM CONUS
        call MR_Set_Met_NCEPGeoGrid(218)

        nt_fullmet = 1
        !np_fullmet = 39
        !np_fullmet_Vz = 39 ! omega
        !np_fullmet_RH = 39  ! rhum
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     875.0_sp, 850.0_sp, 825.0_sp, 800.0_sp, 775.0_sp, &
        !     750.0_sp, 725.0_sp, 700.0_sp, 675.0_sp, 650.0_sp, &
        !     625.0_sp, 600.0_sp, 575.0_sp, 550.0_sp, 525.0_sp, &
        !     500.0_sp, 475.0_sp, 450.0_sp, 425.0_sp, 400.0_sp, &
        !     375.0_sp, 350.0_sp, 325.0_sp, 300.0_sp, 275.0_sp, &
        !     250.0_sp, 225.0_sp, 200.0_sp, 175.0_sp, 150.0_sp, &
        !     125.0_sp, 100.0_sp,  75.0_sp,  50.0_sp /)
        !p_fullmet_Vz_sp(1:np_fullmet_Vz) = p_fullmet_sp(1:np_fullmet)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = p_fullmet_sp(1:np_fullmet)
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet)) 
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        !y_inverted = .false.
        !z_inverted = .true.
      elseif(MR_iwindformat.eq.9)then
          !  5.08 KM CONUS
        call MR_Set_Met_NCEPGeoGrid(227)

        nt_fullmet = 1
        !np_fullmet = 42
        !np_fullmet_Vz = 42 ! omega
        !np_fullmet_RH = 42  ! rhum
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     875.0_sp, 850.0_sp, 825.0_sp, 800.0_sp, 775.0_sp, &
        !     750.0_sp, 725.0_sp, 700.0_sp, 675.0_sp, 650.0_sp, &
        !     625.0_sp, 600.0_sp, 575.0_sp, 550.0_sp, 525.0_sp, &
        !     500.0_sp, 475.0_sp, 450.0_sp, 425.0_sp, 400.0_sp, &
        !     375.0_sp, 350.0_sp, 325.0_sp, 300.0_sp, 275.0_sp, &
        !     250.0_sp, 225.0_sp, 200.0_sp, 175.0_sp, 150.0_sp, &
        !     125.0_sp, 100.0_sp,  75.0_sp,  50.0_sp,  30.0_sp, &
        !      20.0_sp,  10.0_sp /)
        !p_fullmet_Vz_sp(1:np_fullmet_Vz) = p_fullmet_sp(1:np_fullmet)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = p_fullmet_sp(1:np_fullmet)
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet))
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        !y_inverted = .false.
        !z_inverted = .true.

      elseif(MR_iwindformat.eq.10)then
          ! NAM AK 242
        call MR_Set_Met_NCEPGeoGrid(242)

        nt_fullmet = 29
        !np_fullmet = 39
        !np_fullmet_Vz = 29 ! omega
        !np_fullmet_RH = 39  ! rhum
        !np_fullmet_P0 = 1   ! Precip is 2d
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     875.0_sp, 850.0_sp, 825.0_sp, 800.0_sp, 775.0_sp, &
        !     750.0_sp, 725.0_sp, 700.0_sp, 675.0_sp, 650.0_sp, &
        !     625.0_sp, 600.0_sp, 575.0_sp, 550.0_sp, 525.0_sp, &
        !     500.0_sp, 475.0_sp, 450.0_sp, 425.0_sp, 400.0_sp, &
        !     375.0_sp, 350.0_sp, 325.0_sp, 300.0_sp, 275.0_sp, &
        !     250.0_sp, 225.0_sp, 200.0_sp, 175.0_sp, 150.0_sp, &
        !     125.0_sp, 100.0_sp,  75.0_sp,  50.0_sp/)
        !p_fullmet_Vz_sp(1:np_fullmet_Vz) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     875.0_sp, 850.0_sp, 825.0_sp, 800.0_sp, 775.0_sp, &
        !     750.0_sp, 725.0_sp, 700.0_sp, 675.0_sp, 650.0_sp, &
        !     625.0_sp, 600.0_sp, 575.0_sp, 550.0_sp, 525.0_sp, &
        !     500.0_sp, 450.0_sp, 400.0_sp, 350.0_sp, 300.0_sp, &
        !     250.0_sp, 200.0_sp, 150.0_sp, 100.0_sp /)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = p_fullmet_sp(1:np_fullmet)
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet)) 
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        !y_inverted = .false.
        !z_inverted = .true.

      elseif(MR_iwindformat.eq.11)then
          ! NAM196 converted automatically from grib2
        call MR_Set_Met_NCEPGeoGrid(196)

        nt_fullmet = 1
        !np_fullmet = 42
        !np_fullmet_Vz = 42 ! omega
        !np_fullmet_RH = 42  ! rhum
        !np_fullmet_P0 = 1   ! Precip is 2d
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     875.0_sp, 850.0_sp, 825.0_sp, 800.0_sp, 775.0_sp, &
        !     750.0_sp, 725.0_sp, 700.0_sp, 675.0_sp, 650.0_sp, &
        !     625.0_sp, 600.0_sp, 575.0_sp, 550.0_sp, 525.0_sp, &
        !     500.0_sp, 475.0_sp, 450.0_sp, 425.0_sp, 400.0_sp, &
        !     375.0_sp, 350.0_sp, 325.0_sp, 300.0_sp, 275.0_sp, &
        !     250.0_sp, 225.0_sp, 200.0_sp, 175.0_sp, 150.0_sp, &
        !     125.0_sp, 100.0_sp,  75.0_sp,  50.0_sp,  30.0_sp, &
        !      20.0_sp,  10.0_sp /)
        !p_fullmet_Vz_sp(1:np_fullmet_Vz) = p_fullmet_sp(1:np_fullmet)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = p_fullmet_sp(1:np_fullmet)
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet)) 
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        !y_inverted = .false.
        !z_inverted = .true.
      elseif(MR_iwindformat.eq.12)then
          ! NAM198 converted automatically from grib2
        call MR_Set_Met_NCEPGeoGrid(198)

        nt_fullmet = 1
        !np_fullmet = 42
        !np_fullmet_Vz = 42 ! omega
        !np_fullmet_RH = 42  ! rhum
        !np_fullmet_P0 = 1   ! Precip is 2d
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     875.0_sp, 850.0_sp, 825.0_sp, 800.0_sp, 775.0_sp, &
        !     750.0_sp, 725.0_sp, 700.0_sp, 675.0_sp, 650.0_sp, &
        !     625.0_sp, 600.0_sp, 575.0_sp, 550.0_sp, 525.0_sp, &
        !     500.0_sp, 475.0_sp, 450.0_sp, 425.0_sp, 400.0_sp, &
        !     375.0_sp, 350.0_sp, 325.0_sp, 300.0_sp, 275.0_sp, &
        !     250.0_sp, 225.0_sp, 200.0_sp, 175.0_sp, 150.0_sp, &
        !     125.0_sp, 100.0_sp,  75.0_sp,  50.0_sp,  30.0_sp, &
        !      20.0_sp,  10.0_sp /)
        !p_fullmet_Vz_sp(1:np_fullmet_Vz) = p_fullmet_sp(1:np_fullmet)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = p_fullmet_sp(1:np_fullmet)
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet)) 
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        !y_inverted = .false.
        !z_inverted = .true.

      elseif(MR_iwindformat.eq.13)then
          ! NAM91 converted automatically from grib2
        call MR_Set_Met_NCEPGeoGrid(91)

        nt_fullmet = 1
        !np_fullmet = 42
        !np_fullmet_Vz = 42 ! omega
        !np_fullmet_RH = 42  ! rhum
        !np_fullmet_P0 = 1   ! Precip is 2d
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     875.0_sp, 850.0_sp, 825.0_sp, 800.0_sp, 775.0_sp, &
        !     750.0_sp, 725.0_sp, 700.0_sp, 675.0_sp, 650.0_sp, &
        !     625.0_sp, 600.0_sp, 575.0_sp, 550.0_sp, 525.0_sp, &
        !     500.0_sp, 475.0_sp, 450.0_sp, 425.0_sp, 400.0_sp, &
        !     375.0_sp, 350.0_sp, 325.0_sp, 300.0_sp, 275.0_sp, &
        !     250.0_sp, 225.0_sp, 200.0_sp, 175.0_sp, 150.0_sp, &
        !     125.0_sp, 100.0_sp,  75.0_sp,  50.0_sp,  30.0_sp, &
        !      20.0_sp,  10.0_sp /)
        !p_fullmet_Vz_sp(1:np_fullmet_Vz) = p_fullmet_sp(1:np_fullmet)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = p_fullmet_sp(1:np_fullmet)
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet))
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        !y_inverted = .false.
        !z_inverted = .true.
      elseif(MR_iwindformat.eq.14)then
          !  3 KM CONUS)
        call MR_Set_Met_NCEPGeoGrid(1227)

        nt_fullmet = 1
        !np_fullmet = 42
        !np_fullmet_Vz = 42 ! omega
        !np_fullmet_RH = 42  ! rhum
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     875.0_sp, 850.0_sp, 825.0_sp, 800.0_sp, 775.0_sp, &
        !     750.0_sp, 725.0_sp, 700.0_sp, 675.0_sp, 650.0_sp, &
        !     625.0_sp, 600.0_sp, 575.0_sp, 550.0_sp, 525.0_sp, &
        !     500.0_sp, 475.0_sp, 450.0_sp, 425.0_sp, 400.0_sp, &
        !     375.0_sp, 350.0_sp, 325.0_sp, 300.0_sp, 275.0_sp, &
        !     250.0_sp, 225.0_sp, 200.0_sp, 175.0_sp, 150.0_sp, &
        !     125.0_sp, 100.0_sp,  75.0_sp,  50.0_sp,  30.0_sp, &
        !      20.0_sp,  10.0_sp /)
        !p_fullmet_Vz_sp(1:np_fullmet_Vz) = p_fullmet_sp(1:np_fullmet)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = p_fullmet_sp(1:np_fullmet)
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet))
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        !y_inverted = .false.
        !z_inverted = .true.

      elseif(MR_iwindformat.eq.20)then
        ! GFS 0.5
        call MR_Set_Met_NCEPGeoGrid(4)

        nt_fullmet = 1
        !np_fullmet = 31   ! This is for air, hgt, uwnd, vwnd
        !np_fullmet_Vz = 21 ! omega
        !np_fullmet_RH = 31  ! rhum
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     850.0_sp, 800.0_sp, 750.0_sp, 700.0_sp, 650.0_sp, &
        !     600.0_sp, 550.0_sp, 500.0_sp, 450.0_sp, 400.0_sp, &
        !     350.0_sp, 300.0_sp, 250.0_sp, 200.0_sp, 150.0_sp, &
        !     100.0_sp,  70.0_sp,  50.0_sp,  30.0_sp,  20.0_sp, &
        !      10.0_sp,   7.0_sp,   5.0_sp,   3.0_sp,   2.0_sp, &
        !       1.0_sp /)
        !p_fullmet_Vz_sp(1:21) =  &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     850.0_sp, 800.0_sp, 750.0_sp, 700.0_sp, 650.0_sp, &
        !     600.0_sp, 550.0_sp, 500.0_sp, 450.0_sp, 400.0_sp, &
        !     350.0_sp, 300.0_sp, 250.0_sp, 200.0_sp, 150.0_sp, & 
        !     100.0_sp /)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     850.0_sp, 800.0_sp, 750.0_sp, 700.0_sp, 650.0_sp, &
        !     600.0_sp, 550.0_sp, 500.0_sp, 450.0_sp, 400.0_sp, &
        !     350.0_sp, 300.0_sp, 250.0_sp, 200.0_sp, 150.0_sp, & 
        !     100.0_sp,  70.0_sp,  50.0_sp,  30.0_sp,  20.0_sp, &
        !      10.0_sp,   7.0_sp,   5.0_sp,   3.0_sp,   2.0_sp, &
        !       1.0_sp /)
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet)) 
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        y_inverted = .true.
        !z_inverted = .true.

      elseif(MR_iwindformat.eq.21)then
        ! GFS 1.0
        call MR_Set_Met_NCEPGeoGrid(3)

        nt_fullmet = 1
        !np_fullmet = 31   ! This is for air, hgt, uwnd, vwnd
        !np_fullmet_Vz = 21 ! omega
        !np_fullmet_RH = 31  ! rhum
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     850.0_sp, 800.0_sp, 750.0_sp, 700.0_sp, 650.0_sp, &
        !     600.0_sp, 550.0_sp, 500.0_sp, 450.0_sp, 400.0_sp, &
        !     350.0_sp, 300.0_sp, 250.0_sp, 200.0_sp, 150.0_sp, &
        !     100.0_sp,  70.0_sp,  50.0_sp,  30.0_sp,  20.0_sp, &
        !      10.0_sp,   7.0_sp,   5.0_sp,   3.0_sp,   2.0_sp, &
        !       1.0_sp /)
        !p_fullmet_Vz_sp(1:21) =  &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     850.0_sp, 800.0_sp, 750.0_sp, 700.0_sp, 650.0_sp, &
        !     600.0_sp, 550.0_sp, 500.0_sp, 450.0_sp, 400.0_sp, &
        !     350.0_sp, 300.0_sp, 250.0_sp, 200.0_sp, 150.0_sp, &
        !     100.0_sp /)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     850.0_sp, 800.0_sp, 750.0_sp, 700.0_sp, 650.0_sp, &
        !     600.0_sp, 550.0_sp, 500.0_sp, 450.0_sp, 400.0_sp, &
        !     350.0_sp, 300.0_sp, 250.0_sp, 200.0_sp, 150.0_sp, &
        !     100.0_sp,  70.0_sp,  50.0_sp,  30.0_sp,  20.0_sp, &
        !      10.0_sp,   7.0_sp,   5.0_sp,   3.0_sp,   2.0_sp, &
        !       1.0_sp /)
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet))
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        y_inverted = .true.
        !z_inverted = .true.

      elseif(MR_iwindformat.eq.22)then
        ! GFS 0.25
        call MR_Set_Met_NCEPGeoGrid(193)

        nt_fullmet = 1
        !np_fullmet = 31   ! This is for air, hgt, uwnd, vwnd
        !np_fullmet_Vz = 21 ! omega
        !np_fullmet_RH = 31  ! rhum
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     850.0_sp, 800.0_sp, 750.0_sp, 700.0_sp, 650.0_sp, &
        !     600.0_sp, 550.0_sp, 500.0_sp, 450.0_sp, 400.0_sp, &
        !     350.0_sp, 300.0_sp, 250.0_sp, 200.0_sp, 150.0_sp, &
        !     100.0_sp,  70.0_sp,  50.0_sp,  30.0_sp,  20.0_sp, &
        !      10.0_sp,   7.0_sp,   5.0_sp,   3.0_sp,   2.0_sp, &
        !       1.0_sp /)
        !p_fullmet_Vz_sp(1:21) =  &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     850.0_sp, 800.0_sp, 750.0_sp, 700.0_sp, 650.0_sp, &
        !     600.0_sp, 550.0_sp, 500.0_sp, 450.0_sp, 400.0_sp, &
        !     350.0_sp, 300.0_sp, 250.0_sp, 200.0_sp, 150.0_sp, &
        !     100.0_sp /)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     850.0_sp, 800.0_sp, 750.0_sp, 700.0_sp, 650.0_sp, &
        !     600.0_sp, 550.0_sp, 500.0_sp, 450.0_sp, 400.0_sp, &
        !     350.0_sp, 300.0_sp, 250.0_sp, 200.0_sp, 150.0_sp, &
        !     100.0_sp,  70.0_sp,  50.0_sp,  30.0_sp,  20.0_sp, &
        !      10.0_sp,   7.0_sp,   5.0_sp,   3.0_sp,   2.0_sp, & 
        !       1.0_sp /)
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet))
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        y_inverted = .true.
        !z_inverted = .true.
      elseif(MR_iwindformat.eq.23)then
        ! NCEP doE reanalysis
        call MR_Set_Met_NCEPGeoGrid(2)

        nt_fullmet = 1
        !np_fullmet = 17
        !np_fullmet_Vz = 17 ! omega
        !np_fullmet_RH = 17  ! rhum
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 925.0_sp, 850.0_sp, 700.0_sp, 600.0_sp, &
        !     500.0_sp, 400.0_sp, 300.0_sp, 250.0_sp, 200.0_sp, &
        !     150.0_sp, 100.0_sp,  70.0_sp,  50.0_sp,  30.0_sp, &
        !      20.0_sp,  10.0_sp /)
        !p_fullmet_Vz_sp = p_fullmet_sp
        !p_fullmet_RH_sp = p_fullmet_sp
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet)) 
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        y_inverted = .true.
        !z_inverted = .false.
      elseif(MR_iwindformat.eq.24)then
        ! NASA MERRA2 reanalysis
        call MR_Set_Met_NCEPGeoGrid(1024)

        nt_fullmet = 1
        !np_fullmet = 42
        !np_fullmet_Vz = 42 ! omega
        !np_fullmet_RH = 42  ! rhum
        !np_fullmet_P0 = 42  ! Precip is 3d
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     875.0_sp, 850.0_sp, 825.0_sp, 800.0_sp, 775.0_sp, &
        !     750.0_sp, 725.0_sp, 700.0_sp, 650.0_sp, 600.0_sp, &
        !     550.0_sp, 500.0_sp, 450.0_sp, 400.0_sp, 350.0_sp, &
        !     300.0_sp, 250.0_sp, 200.0_sp, 150.0_sp, 100.0_sp, &
        !      70.0_sp,  50.0_sp,  40.0_sp,  30.0_sp,  20.0_sp, &
        !      10.0_sp,   7.0_sp,   5.0_sp,   4.0_sp,   3.0_sp, &
        !       2.0_sp,   1.0_sp,   0.7_sp,   0.5_sp,   0.4_sp, &
        !       0.3_sp,   0.1_sp /)
        !p_fullmet_Vz_sp = p_fullmet_sp
        !p_fullmet_RH_sp = p_fullmet_sp
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet)) 
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        !!y_inverted = .true.
        y_inverted = .false.
        !z_inverted = .false.
      elseif(MR_iwindformat.eq.25)then
        ! NCEP-1 1948 reanalysis
        call MR_Set_Met_NCEPGeoGrid(2)
        nt_fullmet = 1460 ! might need to add 4 for a leap year
        !np_fullmet = 17   ! This is for air, hgt, uwnd, vwnd
        !np_fullmet_Vz = 12 ! omega
        !np_fullmet_RH = 8  ! rhum
        !np_fullmet_P0 = 1  ! Precip is 2d
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 925.0_sp, 850.0_sp, 700.0_sp, 600.0_sp, &
        !     500.0_sp, 400.0_sp, 300.0_sp, 250.0_sp, 200.0_sp, &
        !     150.0_sp, 100.0_sp,  70.0_sp,  50.0_sp, 30.0_sp, &
        !      20.0_sp,  10.0_sp /)
        !p_fullmet_Vz_sp(1:np_fullmet_Vz) = &
        !  (/1000.0_sp, 925.0_sp, 850.0_sp, 700.0_sp, 600.0_sp, &
        !     500.0_sp, 400.0_sp, 300.0_sp, 250.0_sp, 200.0_sp, &
        !     150.0_sp, 100.0_sp /)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = &
        !  (/1000.0_sp, 925.0_sp, 850.0_sp, 700.0_sp, 600.0_sp, &
        !     500.0_sp, 400.0_sp, 300.0_sp /)
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet)) 
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        ! These additional grids are needed since surface variables are on a
        ! different spatial grid.
        do i = 1,192
          x_in_iwf25_sp(i)=(i-1)*1.875_sp
        enddo
        y_in_iwf25_sp(1:94) = (/ &
         88.542_sp,  86.6531_sp,  84.7532_sp,  82.8508_sp,  80.9473_sp,   79.0435_sp,  77.1394_sp, 75.2351_sp, &
        73.3307_sp,  71.4262_sp,  69.5217_sp,  67.6171_sp,  65.7125_sp,   63.8079_sp,  61.9033_sp, 59.9986_sp, &
        58.0939_sp,  56.1893_sp,  54.2846_sp,  52.3799_sp,  50.4752_sp,   48.5705_sp,  46.6658_sp, 44.7611_sp, &
        42.8564_sp,  40.9517_sp,   39.047_sp,  37.1422_sp,  35.2375_sp,   33.3328_sp,  31.4281_sp, 29.5234_sp, &
        27.6186_sp,  25.7139_sp,  23.8092_sp,  21.9044_sp,  19.9997_sp,    18.095_sp,  16.1902_sp, 14.2855_sp, &
        12.3808_sp, 10.47604_sp,  8.57131_sp,  6.66657_sp,  4.76184_sp,    2.8571_sp, 0.952368_sp, &
      -0.952368_sp,  -2.8571_sp, -4.76184_sp, -6.66657_sp, -8.57131_sp, -10.47604_sp, -12.3808_sp, &
       -14.2855_sp, -16.1902_sp,  -18.095_sp, -19.9997_sp, -21.9044_sp,  -23.8092_sp, -25.7139_sp, &
       -27.6186_sp, -29.5234_sp, -31.4281_sp, -33.3328_sp, -35.2375_sp,  -37.1422_sp,  -39.047_sp, &
       -40.9517_sp, -42.8564_sp, -44.7611_sp, -46.6658_sp, -48.5705_sp,  -50.4752_sp, -52.3799_sp, &
       -54.2846_sp, -56.1893_sp, -58.0939_sp, -59.9986_sp, -61.9033_sp,  -63.8079_sp, -65.7125_sp, &
       -67.6171_sp, -69.5217_sp, -71.4262_sp, -73.3307_sp, -75.2351_sp,  -77.1394_sp, -79.0435_sp, &
       -80.9473_sp, -82.8508_sp, -84.7532_sp, -86.6531_sp,  -88.542_sp /)
        !x_inverted = .false.
        y_inverted = .true.
        !z_inverted = .false.
      elseif(MR_iwindformat.eq.26)then
        ! JRA-55 1.25
        call MR_Set_Met_NCEPGeoGrid(45)

        nt_fullmet = 1
        !np_fullmet = 37   ! This is for air, hgt, uwnd, vwnd
        !np_fullmet_Vz = 37 ! omega
        !np_fullmet_RH = 37  ! rhum
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     875.0_sp, 850.0_sp, 825.0_sp, 800.0_sp, 775.0_sp, &
        !     750.0_sp, 700.0_sp, 650.0_sp, 600.0_sp, 550.0_sp, &
        !     500.0_sp, 450.0_sp, 400.0_sp, 350.0_sp, 300.0_sp, &
        !     250.0_sp, 225.0_sp, 200.0_sp, 175.0_sp, 150.0_sp, &
        !     125.0_sp, 100.0_sp,  70.0_sp,  50.0_sp,  30.0_sp, &
        !      20.0_sp,  10.0_sp,   7.0_sp,   5.0_sp,   3.0_sp, &
        !       2.0_sp,   1.0_sp /)

        !p_fullmet_Vz_sp(1:np_fullmet_Vz) = p_fullmet_sp(1:np_fullmet_Vz)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = p_fullmet_sp(1:np_fullmet_RH)

        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet)) 
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        y_inverted = .true.
        !z_inverted = .true.
      elseif(MR_iwindformat.eq.27)then
        ! NOAA reanalysis
        call MR_Set_Met_NCEPGeoGrid(1027)

        nt_fullmet = 1460 ! might need to add 4 for a leap year
        !np_fullmet = 24   ! This is for HGT, TMP, UGRD, VGRD
        !np_fullmet_Vz = 19 ! omega
        !np_fullmet_RH = 19 ! rhum
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        ! ! NOTE: This is the order we ultimately want, but what is in the files
        ! !       is stored top-down (10->1000).
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 950.0_sp, 900.0_sp, 850.0_sp, 800.0_sp, &
        !     750.0_sp, 700.0_sp, 650.0_sp, 600.0_sp, 550.0_sp, &
        !     500.0_sp, 450.0_sp, 400.0_sp, 350.0_sp, 300.0_sp, &
        !     250.0_sp, 200.0_sp, 150.0_sp, 100.0_sp,  70.0_sp, &
        !      50.0_sp,  30.0_sp,  20.0_sp,  10.0_sp /)
        !p_fullmet_Vz_sp(1:np_fullmet_Vz) = &
        !  (/1000.0_sp, 950.0_sp, 900.0_sp, 850.0_sp, 800.0_sp, &
        !     750.0_sp, 700.0_sp, 650.0_sp, 600.0_sp, 550.0_sp, &
        !     500.0_sp, 450.0_sp, 400.0_sp, 350.0_sp, 300.0_sp, &
        !     250.0_sp, 200.0_sp, 150.0_sp, 100.0_sp /)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = p_fullmet_Vz_sp(1:np_fullmet_Vz)
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet)) 
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        y_inverted = .true.
        !z_inverted = .true.
      elseif(MR_iwindformat.eq.28)then
        ! ECMWF Global Gaussian Lat/Lon grid 170
          ! Note: grid is not regular
          !       pressure values are from low to high
        call MR_Set_Met_NCEPGeoGrid(170)

        nt_fullmet = 1
        !np_fullmet = 37   ! This is for air, hgt, uwnd, vwnd
        !np_fullmet_Vz = 37 ! omega
        !np_fullmet_RH = 37  ! rhum
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        ! ! NOTE: This is the order we ultimately want, but what is in the files
        ! !       is stored top-down (1->1000).
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     875.0_sp, 850.0_sp, 825.0_sp, 800.0_sp, 775.0_sp, &
        !     750.0_sp, 700.0_sp, 650.0_sp, 600.0_sp, 550.0_sp, &
        !     500.0_sp, 450.0_sp, 400.0_sp, 350.0_sp, 300.0_sp, &
        !     250.0_sp, 225.0_sp, 200.0_sp, 175.0_sp, 150.0_sp, &
        !     125.0_sp, 100.0_sp,  70.0_sp,  50.0_sp,  30.0_sp, &
        !      20.0_sp,  10.0_sp,   7.0_sp,   5.0_sp,   3.0_sp, &
        !       2.0_sp,   1.0_sp /)
        !p_fullmet_Vz_sp(1:np_fullmet_Vz) = p_fullmet_sp(1:np_fullmet)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = p_fullmet_sp(1:np_fullmet)
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet)) 
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        y_inverted = .true.
        !z_inverted = .true.
      elseif(MR_iwindformat.eq.29)then
        ! ECMWF Global Gaussian Lat/Lon 
        call MR_Set_Met_NCEPGeoGrid(1029)

        nt_fullmet = 1
        !np_fullmet = 37   ! This is for air, hgt, uwnd, vwnd
        !np_fullmet_Vz = 37 ! omega
        !np_fullmet_RH = 37  ! rhum
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     875.0_sp, 850.0_sp, 825.0_sp, 800.0_sp, 775.0_sp, &
        !     750.0_sp, 700.0_sp, 650.0_sp, 600.0_sp, 550.0_sp, &
        !     500.0_sp, 450.0_sp, 400.0_sp, 350.0_sp, 300.0_sp, &
        !     250.0_sp, 225.0_sp, 200.0_sp, 175.0_sp, 150.0_sp, &
        !     125.0_sp, 100.0_sp,  70.0_sp,  50.0_sp,  30.0_sp, &
        !      20.0_sp,  10.0_sp,   7.0_sp,   5.0_sp,   3.0_sp, &
        !       2.0_sp,   1.0_sp /)

        !p_fullmet_Vz_sp(1:np_fullmet_Vz) = p_fullmet_sp(1:np_fullmet_Vz)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = p_fullmet_sp(1:np_fullmet_RH)

        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet))
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        y_inverted = .true.
        !z_inverted = .true.

      elseif(MR_iwindformat.eq.31)then
          ! Catania forecasts
        call MR_Set_Met_NCEPGeoGrid(1031)

        nt_fullmet = 1
        !np_fullmet = 13
        !np_fullmet_Vz = 13 ! omega
        !np_fullmet_RH = 13  ! rhum
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 950.0_sp, 925.0_sp, 850.0_sp, 700.0_sp, &
        !     600.0_sp, 500.0_sp, 400.0_sp, 300.0_sp, 250.0_sp, &
        !     200.0_sp, 150.0_sp, 100.0_sp /)
        !p_fullmet_Vz_sp(1:np_fullmet_Vz) = p_fullmet_sp(1:np_fullmet)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = p_fullmet_sp(1:np_fullmet)
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet)) 
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        y_inverted = .false.
        !z_inverted = .false.

      elseif(MR_iwindformat.eq.32)then
          ! Air Force Weather Agency
        call MR_Set_Met_NCEPGeoGrid(1032)

! isobaric = 1000, 5000, 10000, 20000, 25000, 30000, 40000, 50000, 70000, 
!    85000, 92500, 100000 ;
! isobaric1 = 85000 ;
! isobaric2 = 1000, 5000, 10000, 20000, 25000, 50000, 70000, 85000, 92500, 
!    100000 ;

        nt_fullmet = 1
        !np_fullmet = 39
        !np_fullmet_Vz = 31 ! omega
        !np_fullmet_RH = 39  ! rhum
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1013.0_sp, 1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, &
        !     900.0_sp,  875.0_sp, 850.0_sp, 825.0_sp, 800.0_sp, &
        !     775.0_sp,  750.0_sp, 725.0_sp, 700.0_sp, 650.0_sp, &
        !     600.0_sp,  550.0_sp, 500.0_sp, 450.0_sp, 400.0_sp, &
        !     350.0_sp,  300.0_sp, 250.0_sp, 200.0_sp, 150.0_sp, &
        !     100.0_sp,   70.0_sp,  50.0_sp,  30.0_sp,  20.0_sp, &
        !      10.0_sp,    3.0_sp,   2.0_sp,   1.0_sp,   0.5_sp, &
        !       0.3_sp,    0.2_sp,   0.1_sp,   0.05_sp/)
        !p_fullmet_Vz_sp(1:np_fullmet_Vz) = &
        !  (/1013.0_sp, 1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, &
        !     900.0_sp,  875.0_sp, 850.0_sp, 825.0_sp, 800.0_sp, &
        !     775.0_sp,  750.0_sp, 725.0_sp, 700.0_sp, 650.0_sp, &
        !     600.0_sp,  550.0_sp, 500.0_sp, 450.0_sp, 400.0_sp, &
        !     350.0_sp,  300.0_sp, 250.0_sp, 200.0_sp, 150.0_sp, &
        !     100.0_sp,   70.0_sp,  50.0_sp,  30.0_sp,  20.0_sp, &
        !      10.0_sp/)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = p_fullmet_sp(1:np_fullmet)

        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet)) 
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        x_inverted = .false.
        y_inverted = .false.
        !z_inverted = .true.

      elseif(MR_iwindformat.eq.33)then
          ! CAM paleoclimate
        call MR_Set_Met_NCEPGeoGrid(1033)

        nt_fullmet = 120
        !np_fullmet = 26
        !np_fullmet_Vz = 26 ! omega
        !np_fullmet_RH = 26  ! rhum
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/ 992.6_sp,  970.6_sp, 929.6_sp, 867.2_sp, 787.7_sp, &
        !     696.8_sp,  600.5_sp, 510.5_sp, 433.9_sp, 368.8_sp, &
        !     313.5_sp,  266.5_sp, 226.5_sp, 192.5_sp, 163.7_sp, &
        !     139.1_sp,  118.3_sp, 100.5_sp,  85.4_sp,  70.1_sp, &
        !      53.1_sp,   37.2_sp,  23.9_sp,  14.0_sp,   7.4_sp, &
        !       3.5_sp/)
        !p_fullmet_Vz_sp(1:np_fullmet_Vz) = p_fullmet_sp(1:np_fullmet)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = p_fullmet_sp(1:np_fullmet)
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet))
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        y_inverted = .false.
        !z_inverted = .true.

      elseif(MR_iwindformat.eq.40)then
        ! NASA GEOS Cp
        call MR_Set_Met_NCEPGeoGrid(1040)

        nt_fullmet = 1
        !np_fullmet = 37
        !np_fullmet_Vz = 37 ! omega
        !np_fullmet_RH = 37  ! rhum
        !np_fullmet_P0 = 37  ! Precip is 3d
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     875.0_sp, 850.0_sp, 825.0_sp, 800.0_sp, 775.0_sp, &
        !     750.0_sp, 725.0_sp, 700.0_sp, 650.0_sp, 600.0_sp, &
        !     550.0_sp, 500.0_sp, 450.0_sp, 400.0_sp, 350.0_sp, &
        !     300.0_sp, 250.0_sp, 200.0_sp, 150.0_sp, 100.0_sp, &
        !      70.0_sp,  50.0_sp,  40.0_sp,  30.0_sp,  20.0_sp, &
        !      10.0_sp,   7.0_sp,   5.0_sp,   4.0_sp,   3.0_sp, &
        !       2.0_sp,   1.0_sp /)
        !p_fullmet_Vz_sp = p_fullmet_sp
        !p_fullmet_RH_sp = p_fullmet_sp
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet))
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        y_inverted = .false.
        !z_inverted = .false.

      elseif(MR_iwindformat.eq.41)then
        ! NASA GEOS Np
        call MR_Set_Met_NCEPGeoGrid(1041)

        nt_fullmet = 1
        !np_fullmet = 42
        !np_fullmet_Vz = 42 ! omega
        !np_fullmet_RH = 42  ! rhum
        np_fullmet_P0 = 42  ! Precip is 3d
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     875.0_sp, 850.0_sp, 825.0_sp, 800.0_sp, 775.0_sp, &
        !     750.0_sp, 725.0_sp, 700.0_sp, 650.0_sp, 600.0_sp, &
        !     550.0_sp, 500.0_sp, 450.0_sp, 400.0_sp, 350.0_sp, &
        !     300.0_sp, 250.0_sp, 200.0_sp, 150.0_sp, 100.0_sp, &
        !      70.0_sp,  50.0_sp,  40.0_sp,  30.0_sp,  20.0_sp, &
        !      10.0_sp,   7.0_sp,   5.0_sp,   4.0_sp,   3.0_sp, &
        !       2.0_sp,   1.0_sp,   0.7_sp,   0.5_sp,   0.4_sp, &
        !       0.3_sp,   0.1_sp /)
        !p_fullmet_Vz_sp = p_fullmet_sp
        !p_fullmet_RH_sp = p_fullmet_sp
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet))
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        y_inverted = .false.
        !z_inverted = .false.

      elseif(MR_iwindformat.eq.50)then
         ! WRF - output

        call MR_Get_WRF_grid

      elseif(MR_iwindformat.eq.51)then
          ! SENAMHI WRF 22 km
        call MR_Set_Met_NCEPGeoGrid(1051)

        nt_fullmet = 1
        !np_fullmet = 15
        !np_fullmet_Vz = 15 ! omega
        !np_fullmet_RH = 15  ! rhum
        !np_fullmet_P0 = 1   ! Precip is 2d
        !allocate(p_fullmet_sp(np_fullmet))
        !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
        !allocate(p_fullmet_RH_sp(np_fullmet_RH))
        !p_fullmet_sp(1:np_fullmet) = &
        !  (/1000.0_sp, 975.0_sp, 950.0_sp, 925.0_sp, 900.0_sp, &
        !     850.0_sp, 700.0_sp, 600.0_sp, 500.0_sp, 400.0_sp, &
        !     300.0_sp, 250.0_sp, 200.0_sp, 100.0_sp,  50.0_sp /)
        !p_fullmet_Vz_sp(1:np_fullmet_Vz) = p_fullmet_sp(1:np_fullmet)
        !p_fullmet_RH_sp(1:np_fullmet_RH) = p_fullmet_sp(1:np_fullmet)
        !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet))
        !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
        !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa
        !x_inverted = .false.
        y_inverted = .false.
        !z_inverted = .true.

      else
        ! Not a recognized MR_iwindformat
        ! call reading of template windfile pressure,grid values
        write(MR_global_info,*)"windfile format not recognized."
        stop 1
      endif

      allocate(z_approx(np_fullmet))
      do k=1,np_fullmet
        ! Calculate heights for US Std Atmos while pressures are still in mbars
        ! or hPa
        z_approx(k) = MR_Z_US_StdAtm(p_fullmet_sp(k))
      enddo

      write(MR_global_info,*)"Dimension info:"
      write(MR_global_info,*)"  record (time): ",nt_fullmet
      write(MR_global_info,*)"  level  (z)   : ",np_fullmet
      write(MR_global_info,*)"  y            : ",ny_fullmet
      write(MR_global_info,*)"  x            : ",nx_fullmet

      !************************************************************************
      ! assign boundaries of mesoscale model
      if(x_inverted)then
          ! I know of no windfiles with x-coordinate reversed
        xLL_fullmet = x_fullmet_sp(nx_fullmet)
        xUR_fullmet = x_fullmet_sp(1)
      else
        xLL_fullmet = x_fullmet_sp(1)
        xUR_fullmet = x_fullmet_sp(nx_fullmet)
      endif

      if(y_inverted)then
          ! Most lon/lat grids have y reversed
        yLL_fullmet = y_fullmet_sp(ny_fullmet)
        yUR_fullmet = y_fullmet_sp(1)
      else
          ! Projected grids have y not reversed
        yLL_fullmet = y_fullmet_sp(1)
        yUR_fullmet = y_fullmet_sp(ny_fullmet)
      endif

      write(MR_global_production,*)"--------------------------------------------------------------------------------"

      end subroutine MR_Read_Met_DimVars_netcdf

!##############################################################################


!##############################################################################
!
!     MR_Get_WRF_grid
!
!     Called once from MR_Read_Met_DimVars_netcdf
!
!     This subroutine reads the variable and dimension IDs, and fills the
!     coordinate dimension variables, just like MR_Read_Met_DimVars_netcdf,
!     but WRF files are a bit more complicated than most since the grid/projection can
!     vary and state variables (U,V,W,Gph) are each on grids staggered in the
!     relevant direction.
!
!     After this subroutine completes, the following variables will be set:
!       All the projection parameters of NWP grid
!       Met_dim_names, Met_var_names, Met_var_conversion_factor, Met_var_IsAvailable
!       The lengths of all the dimensions of the file
!       p_fullmet_sp (converted to Pa)
!       x_fullmet_sp, y_fullmet_sp
!       IsLatLon_MetGrid, IsGlobal_MetGrid, IsRegular_MetGrid 
!
!##############################################################################

      subroutine MR_Get_WRF_grid

      use MetReader
      use netcdf
      use projection

      implicit none

      integer, parameter :: sp        = 4 ! single precision
      integer, parameter :: dp        = 8 ! double precision

      integer :: nSTAT
      integer :: ncid

      character(len = nf90_max_name) :: name_dum

      integer :: t_dim_id          = 0 ! x or lon
      integer :: x_dim_id          = 0 ! x or lon
      integer :: y_dim_id          = 0 ! y or lat
      integer :: z_dim_id          = 0 ! x or lon

      integer :: lon_var_id
      integer :: lat_var_id
      integer :: PB_var_id
      integer :: Ppert_var_id

      integer :: Map_Proj
      real(kind=sp) :: WRF_dx,WRF_dy
      real(kind=sp) :: Cen_lat,Stand_Lon,Truelat1,Truelat2
      real(kind=sp),dimension(:,:,:)  ,allocatable :: dum3d_sp
      real(kind=sp),dimension(:,:,:,:),allocatable :: dum4d_sp
      integer :: i

      real(kind=dp) :: x_start,y_start

      real(kind=dp) :: lat_in,lon_in

        ! MAP_PROJ - Model projection  1=Lambert, 2=polar stereographic, 
        !                              3=mercator, 6=lat-lon

        ! First set spatial (x/y) grid
        ! Open first windfile and assume all grids are the same

      write(MR_global_info,*)"About to open first WRF file : ",MR_windfiles(1)
      nSTAT=nf90_open(adjustl(trim(MR_windfiles(1))),NF90_NOWRITE, ncid)
      if(nSTAT.ne.NF90_NOERR) then
        write(MR_global_error,*)'MR ERROR: open WRF file: ',nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: open WRF file: ',nf90_strerror(nSTAT)
        write(MR_global_error,*)'Exiting'
        stop 1
      endif
      
      Met_dim_names(1) = "Time"       ! time
      Met_dim_names(2) = "bottom_top"      ! pressure (24 levels 10 -> 1000)
      Met_dim_names(3) = "south_north"      ! y        (90.0 -> -90.0)
      Met_dim_names(4) = "west_east"      ! x        (0.0 -> 378.0)
      Met_dim_names(5) = "bottom_top_stag"      ! Stag in Z (pressure coordinate for Vz)
      Met_dim_names(6) = "west_east_stag"       ! Stag in x
      Met_dim_names(7) = "south_north_stag"     ! Stag in y

      ! Get dim ids and sizes
      nSTAT = nf90_inq_dimid(ncid,Met_dim_names(1),t_dim_id)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: inq_dimid Time: ',nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: inq_dimid Time: ',nf90_strerror(nSTAT)
        stop 1
      endif
      nSTAT = nf90_Inquire_Dimension(ncid,t_dim_id,name=name_dum,len=nt_fullmet)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: Inquire_Dimension Time: ', &
                             nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: Inquire_Dimension Time: ', &
                             nf90_strerror(nSTAT)
        stop 1
      endif 
      nSTAT = nf90_inq_dimid(ncid,Met_dim_names(4),x_dim_id)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: inq_dimid x: ',nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: inq_dimid x: ',nf90_strerror(nSTAT)
        stop 1
      endif

      nSTAT = nf90_Inquire_Dimension(ncid,x_dim_id,name=name_dum,len=nx_fullmet)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: Inquire_Dimension x: ', &
                             nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: Inquire_Dimension x: ', &
                             nf90_strerror(nSTAT)
        stop 1
      endif

      nSTAT = nf90_inq_dimid(ncid,Met_dim_names(3),y_dim_id)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: inq_dimid y: ',nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: inq_dimid y: ',nf90_strerror(nSTAT)
        stop 1
      endif

      nSTAT = nf90_Inquire_Dimension(ncid,y_dim_id,name=name_dum,len=ny_fullmet)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: Inquire_Dimension y: ', &   
                             nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: Inquire_Dimension y: ', &
                             nf90_strerror(nSTAT)
        stop 1
      endif

      nSTAT = nf90_inq_dimid(ncid,Met_dim_names(2),z_dim_id)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: inq_dimid z: ',nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: inq_dimid z: ',nf90_strerror(nSTAT)
        stop 1
      endif

      nSTAT = nf90_Inquire_Dimension(ncid,z_dim_id,name=name_dum,len=neta_fullmet)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: Inquire_Dimension z: ', &
                             nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: Inquire_Dimension z: ', &
                             nf90_strerror(nSTAT)
        stop 1
      endif

      nSTAT = nf90_get_att(ncid, NF90_GLOBAL, "MAP_PROJ", Map_Proj)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: get_att MAP_PROJ: ', &
                             nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: get_att MAP_PROJ: ', &
                             nf90_strerror(nSTAT)
        stop 1
      endif

      if(Map_Proj.eq.1)then
         ! Lambert
         !   truelat1
         !   truelat2 (optional)
         !   stand_lon
         !proj +proj=lcc +lon_0=-175.0 +lat_0=55.0 +lat_1=50.0 +lat_2=60.0 +R=6371.229

        nSTAT = nf90_get_att(ncid, NF90_GLOBAL, "DX", WRF_dx)
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: get_att DX: ',nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: get_att DX: ',nf90_strerror(nSTAT)
          stop 1
        endif
        nSTAT = nf90_get_att(ncid, NF90_GLOBAL, "DY", WRF_dy)
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: get_att DY: ',nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: get_att DY: ',nf90_strerror(nSTAT)
          stop 1
        endif
        nSTAT = nf90_get_att(ncid, NF90_GLOBAL, "CEN_LAT", Cen_Lat)
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: get_att CEN_LAT: ',nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: get_att CEN_LAT: ',nf90_strerror(nSTAT)
          stop 1
        endif
        nSTAT = nf90_get_att(ncid, NF90_GLOBAL, "STAND_LON", Stand_Lon)
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: get_att STAND_LON: ',nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: get_att STAND_LON: ',nf90_strerror(nSTAT)
          stop 1
        endif
        nSTAT = nf90_get_att(ncid, NF90_GLOBAL, "TRUELAT1", Truelat1)
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: get_att TRUELAT1: ',nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: get_att TRUELAT1: ',nf90_strerror(nSTAT)
          stop 1
        endif
        nSTAT = nf90_get_att(ncid, NF90_GLOBAL, "TRUELAT2", Truelat2)
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: get_att TRUELAT2: ',nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: get_att TRUELAT2: ',nf90_strerror(nSTAT)
          stop 1
        endif

          ! convert dx, dy to km
        IsRegular_MetGrid = .true.
        dx_met_const = WRF_dx*1.0e-3_4
        dy_met_const = WRF_dy*1.0e-3_4

        ! Projected grids have Lon and Lat provided as 2d fields
        allocate(Met_Proj_lat(nx_fullmet,ny_fullmet))
        allocate(Met_Proj_lon(nx_fullmet,ny_fullmet))
        allocate(dum3d_sp(nx_fullmet,ny_fullmet,1))

        nSTAT = nf90_inq_varid(ncid,"XLONG",lon_var_id)
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: inq_varid XLONG: ',nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: inq_varid XLONG: ',nf90_strerror(nSTAT)
          stop 1
        endif
        nSTAT = nf90_inq_varid(ncid,"XLAT",lat_var_id)
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: inq_varid XLAT: ',nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: inq_varid XLAT: ',nf90_strerror(nSTAT)
          stop 1
        endif

        nSTAT = nf90_get_var(ncid,lon_var_id,dum3d_sp, &
               start = (/1,1,1/),count = (/nx_fullmet,ny_fullmet,1/))
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: get_var XLONG: ',nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: get_var XLONG: ',nf90_strerror(nSTAT)
          stop 1
        endif
           Met_Proj_lon(:,:) = dum3d_sp(:,:,1)
        nSTAT = nf90_get_var(ncid,lat_var_id,dum3d_sp, &
               start = (/1,1,1/),count = (/nx_fullmet,ny_fullmet,1/))
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: get_var XLAT: ',nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: get_var XLAT: ',nf90_strerror(nSTAT)
          stop 1
        endif
           Met_Proj_lat(:,:) = dum3d_sp(:,:,1)

        ! In the example WRF files, x and y projected values are not actually
        ! provided, so we recreate them here using the coordinates if the LL
        ! point of the Lon/Lat grid
        allocate(x_fullmet_sp(nx_fullmet))
        allocate(y_fullmet_sp(ny_fullmet))
        allocate(MR_dx_met(nx_fullmet))
        allocate(MR_dy_met(ny_fullmet))

        lon_in = real(Met_Proj_lon(1,1),kind=8)
        lat_in = real(Met_Proj_lat(1,1),kind=8)

          ! Setting the projection parameters as libprojection.a expects
        Met_iprojflag = 4  
        Met_lam0   = real(Stand_Lon,kind=8)
        Met_phi0   = real(Cen_Lat,kind=8)
        Met_phi1   = real(Truelat1,kind=8)
        Met_phi2   = real(Truelat2,kind=8)
        Met_k0     = real(1.0,kind=8)
        Met_Re     = PJ_radius_earth
        call PJ_proj_for(lon_in,lat_in, &
                       Met_iprojflag,Met_lam0,Met_phi0,Met_phi1,Met_phi2,Met_k0,Met_Re, &
                       x_start,y_start)
        do i = 1,nx_fullmet
          x_fullmet_sp(i) = real(x_start + (i-1)*dx_met_const,kind=4)
        enddo
        do i = 1,ny_fullmet
          y_fullmet_sp(i) = real(y_start + (i-1)*dy_met_const,kind=4)
        enddo
        do i = 1,nx_fullmet-1
          MR_dx_met(i) = x_fullmet_sp(i+1)-x_fullmet_sp(i)
        enddo
        MR_dx_met(nx_fullmet)    = MR_dx_met(nx_fullmet-1)
        do i = 1,ny_fullmet-1
          MR_dy_met(i) = y_fullmet_sp(i+1)-y_fullmet_sp(i)
        enddo
        MR_dy_met(ny_fullmet)    = MR_dy_met(ny_fullmet-1)

      elseif(Map_Proj.eq.2)then
        ! Polar Stereographic
        !   truelat1
        !   stand_lon
        write(MR_global_info,*)&
         "WRF: MAP_PROJ=2 : Polar Stereographic : Not implemented"
        stop 1
      elseif(Map_Proj.eq.3)then
        ! Mercator
        !  truelat1
         ! stand_lon
         !proj +proj=merc 

        nSTAT = nf90_get_att(ncid, NF90_GLOBAL, "DX", WRF_dx)
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: get_att DX: ',nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: get_att DX: ',nf90_strerror(nSTAT)
          stop 1
        endif
        nSTAT = nf90_get_att(ncid, NF90_GLOBAL, "DY", WRF_dy)
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: get_att DY: ',nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: get_att DY: ',nf90_strerror(nSTAT)
          stop 1
        endif
        nSTAT = nf90_get_att(ncid, NF90_GLOBAL, "CEN_LAT", Cen_Lat)
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: get_att CEN_LAT: ',nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: get_att CEN_LAT: ',nf90_strerror(nSTAT)
          stop 1
        endif
        nSTAT = nf90_get_att(ncid, NF90_GLOBAL, "STAND_LON", Stand_Lon)
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: get_att STAND_LON: ',nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: get_att STAND_LON: ',nf90_strerror(nSTAT)
          stop 1
        endif
        nSTAT = nf90_get_att(ncid, NF90_GLOBAL, "TRUELAT1", Truelat1)
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: get_att TRUELAT1: ',nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: get_att TRUELAT1: ',nf90_strerror(nSTAT)
          stop 1
        endif
        nSTAT = nf90_get_att(ncid, NF90_GLOBAL, "TRUELAT2", Truelat2)
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: get_att TRUELAT2: ',nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: get_att TRUELAT2: ',nf90_strerror(nSTAT)
          stop 1
        endif

          ! convert dx, dy to km
        IsRegular_MetGrid = .true.
        dx_met_const = WRF_dx*1.0e-3_4
        dy_met_const = WRF_dy*1.0e-3_4

        ! Projected grids have Lon and Lat provided as 2d fields
        allocate(Met_Proj_lat(nx_fullmet,ny_fullmet))
        allocate(Met_Proj_lon(nx_fullmet,ny_fullmet))
        allocate(dum3d_sp(nx_fullmet,ny_fullmet,1))

        nSTAT = nf90_inq_varid(ncid,"XLONG",lon_var_id)
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: inq_varid XLONG: ',nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: inq_varid XLONG: ',nf90_strerror(nSTAT)
          stop 1
        endif
        nSTAT = nf90_inq_varid(ncid,"XLAT",lat_var_id)
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: inq_varid XLAT: ',nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: inq_varid XLAT: ',nf90_strerror(nSTAT)
          stop 1
        endif

        nSTAT = nf90_get_var(ncid,lon_var_id,dum3d_sp, &
               start = (/1,1,1/),count = (/nx_fullmet,ny_fullmet,1/))
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: get_var XLONG: ',nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: get_var XLONG: ',nf90_strerror(nSTAT)
          stop 1
        endif
           Met_Proj_lon(:,:) = dum3d_sp(:,:,1)
        nSTAT = nf90_get_var(ncid,lat_var_id,dum3d_sp, &
               start = (/1,1,1/),count = (/nx_fullmet,ny_fullmet,1/))
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: get_var XLAT: ',nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: get_var XLAT: ',nf90_strerror(nSTAT)
          stop 1
        endif
           Met_Proj_lat(:,:) = dum3d_sp(:,:,1)

        ! In the example WRF files, x and y projected values are not actually
        ! provided, so we recreate them here using the coordinates if the LL
        ! point of the Lon/Lat grid
        allocate(x_fullmet_sp(nx_fullmet))
        allocate(y_fullmet_sp(ny_fullmet))
        allocate(MR_dx_met(nx_fullmet))
        allocate(MR_dy_met(ny_fullmet))

        lon_in = real(Met_Proj_lon(1,1),kind=8)
        lat_in = real(Met_Proj_lat(1,1),kind=8)

          ! Setting the projection parameters as libprojection.a expects
        Met_iprojflag = 5
        Met_lam0   = real(Stand_Lon,kind=8)
        Met_phi0   = real(Cen_Lat,kind=8)
        Met_phi1   = real(Truelat1,kind=8)
        Met_phi2   = real(Truelat2,kind=8)
        Met_k0     = real(1.0,kind=8)
        Met_Re     = PJ_radius_earth
        call PJ_proj_for(lon_in,lat_in, &
                       Met_iprojflag,Met_lam0,Met_phi0,Met_phi1,Met_phi2,Met_k0,Met_Re, &
                       x_start,y_start)
        do i = 1,nx_fullmet
          x_fullmet_sp(i) = real(x_start + (i-1)*dx_met_const,kind=4)
        enddo
        do i = 1,ny_fullmet
          y_fullmet_sp(i) = real(y_start + (i-1)*dy_met_const,kind=4)
        enddo
        do i = 1,nx_fullmet-1
          MR_dx_met(i) = x_fullmet_sp(i+1)-x_fullmet_sp(i)
        enddo
        MR_dx_met(nx_fullmet)    = MR_dx_met(nx_fullmet-1)
        do i = 1,ny_fullmet-1
          MR_dy_met(i) = y_fullmet_sp(i+1)-y_fullmet_sp(i)
        enddo
        MR_dy_met(ny_fullmet)    = MR_dy_met(ny_fullmet-1)

      elseif(Map_Proj.eq.6)then
        ! Lon-Lat or cylindrical equidistant
        !   pole_lat
        !   pole_lon
        !   stand_lon
        write(MR_global_info,*)"WRF: MAP_PROJ=6 : Lon-Lat : Not implemented"
        stop 1
      else
        write(MR_global_info,*)&
         "The MAP_PROJ global attribute is either not present or is"
        write(MR_global_info,*)"not a recognized projection."
        stop 1
      endif

      ! Now setting up pressure coordinate
      ! WRF data are provided on eta levels instead of pressure level
      ! Fortunately, it will usually be adequate to pretend that they are on
      ! pressure levels since Ash3d interpolates onto a z-grid using GPH.
      ! The "atmosphere" module, will need access to physical pressure and will
      ! need a special case for WRF files
      np_fullmet    = neta_fullmet
      !np_fullmet_Vz = neta_fullmet ! Vz is actually on a staggered grid, but
                                   ! will be interpolated onto the non-staggered grid
      !np_fullmet_RH = neta_fullmet
      allocate(p_fullmet_sp(np_fullmet))
      !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
      !allocate(p_fullmet_RH_sp(np_fullmet_RH))
      allocate(dum4d_sp(nx_fullmet,ny_fullmet,np_fullmet,1))

      ! To populate a place-holder p_fullmet_sp, read the full pressure grid and
      ! copy a representative column
      nSTAT = nf90_inq_varid(ncid,"PB",PB_var_id)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: inq_varid PB: ',nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: inq_varid PB: ',nf90_strerror(nSTAT)
        stop 1
      endif

      nSTAT = nf90_get_var(ncid,PB_var_id,dum4d_sp, &
             start = (/1,1,1,1/),count = (/nx_fullmet,ny_fullmet,neta_fullmet,1/))
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: get_var PB: ',nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: get_var PB: ',nf90_strerror(nSTAT)
        stop 1
      endif
         p_fullmet_sp(:) = dum4d_sp(1,1,:,1)
      nSTAT = nf90_inq_varid(ncid,"P",Ppert_var_id)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: inq_varid P: ',nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: inq_varid P: ',nf90_strerror(nSTAT)
        stop 1
      endif
      nSTAT = nf90_get_var(ncid,Ppert_var_id,dum4d_sp, &
             start = (/1,1,1,1/),count = (/nx_fullmet,ny_fullmet,neta_fullmet,1/))
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: get_var P: ',nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: get_var P: ',nf90_strerror(nSTAT)
        stop 1
      endif
         p_fullmet_sp(:) = p_fullmet_sp(:) + dum4d_sp(1,1,:,1)
      !p_fullmet_Vz_sp = p_fullmet_sp
      !p_fullmet_RH_sp = p_fullmet_sp
      MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet)*0.01_sp) 

      !p_fullmet_sp    = p_fullmet_sp    * 100.0_sp   ! convert from hPa to Pa
      !p_fullmet_Vz_sp = p_fullmet_Vz_sp * 100.0_sp   ! convert from hPa to Pa
      !p_fullmet_RH_sp = p_fullmet_RH_sp * 100.0_sp   ! convert from hPa to Pa

       x_inverted = .false.
       y_inverted = .false.
       z_inverted = .false.

       ! Close file
       nSTAT = nf90_close(ncid)
       if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: close WRF file: ',nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: close WRF file: ',nf90_strerror(nSTAT)
          stop 1
       endif

       nlev_coords_detected = 1
       allocate(nlevs_fullmet(nlev_coords_detected))
       nlevs_fullmet(1) = np_fullmet
       allocate(levs_code(nlev_coords_detected))
       levs_code(1) = 1
       allocate(levs_fullmet_sp(nlev_coords_detected,np_fullmet))
       levs_fullmet_sp(1,1:np_fullmet) = p_fullmet_sp(1:np_fullmet)

       Met_var_zdim_idx(:)  = 1
       !Met_var_zdim_ncid(ivar) = var_dimIDs(i_dim)


       end subroutine MR_Get_WRF_grid

!##############################################################################
!
!     MR_Read_Met_Times_netcdf
!
!     Called once from MR_Read_Met_DimVars 
!
!     This subroutine opens each netcdf file and determine the time of each
!     time step of each file in the number of hours since MR_BaseYear.
!     In most cases, the length of the time variable (nt_fullmet) will be 
!     read directly from the file and overwritten (is was set in MR_Read_Met_DimVars_netcdf
!     above).
!
!     After this subroutine completes, the following variables will be set:
!       MR_windfile_starthour(MR_iwindfiles)
!       MR_windfile_stephour(MR_iwindfiles,nt_fullmet)
!
!##############################################################################

      subroutine MR_Read_Met_Times_netcdf

      use MetReader
      use netcdf

      implicit none

      integer, parameter :: sp        = 4 ! single precision
      integer, parameter :: dp        = 8 ! double precision

      integer :: iw,iws
      integer :: itstart_year,itstart_month
      integer :: itstart_day
      real(kind=sp) :: filestart_hour

      integer :: itstart_hour,itstart_min,itstart_sec

      integer :: nSTAT
      integer :: ncid
      integer :: time_var_id = 0
      integer :: reftime_var_id
      integer :: t_dim_id
      real(kind=sp),dimension(:),allocatable :: filetime_in_sp
      character(len=19) :: Timestr_WRF
      integer :: filetime_in_int

      integer            :: var_xtype
      character(len=NF90_MAX_NAME)  :: name,invar
      integer            :: xtype, length, attnum
      character(len=20)  :: tstring
      character(len=31)  :: tstring2
      real(kind=8)       :: HS_hours_since_baseyear !,HS_HourOfDay
      character(len=130) :: dumstr
      integer            :: iwstep
      logical            :: TimeHasUnitsAttr = .false.
      integer            :: i,ii
      real(kind=dp),dimension(:), allocatable :: dum1d_dp
      real(kind=sp),dimension(:), allocatable :: dum1d_sp
      integer(kind=4),dimension(:), allocatable :: dum1d_int4
      integer,dimension(8) :: values
      integer              :: Current_Year,nt_tst
      character(len=130)   :: infile

      write(MR_global_production,*)"--------------------------------------------------------------------------------"
      write(MR_global_production,*)"----------                MR_Read_Met_Times_netcdf                    ----------"
      write(MR_global_production,*)"--------------------------------------------------------------------------------"

      if(.not.Met_dim_IsAvailable(1))then
        write(MR_global_error,*)"MR ERROR: Time dimension is required and not listed"
        write(MR_global_error,*)"          in template windfile specification file."
        stop 1
      endif

      allocate(MR_windfile_starthour(MR_iwindfiles))
      if(MR_iwindformat.eq.25.or.MR_iwindformat.eq.27)then
        ! Here the branch for when MR_iwindformat = 25 or 27
        ! First copy path read in to slot 2
        !if(MR_runAsForecast)then
        !  write(MR_global_error,*)"MR ERROR: iwf=25 and 27 cannot be used for forecast runs."
        !  write(MR_global_error,*)"          These are reanalysis files."
        !  stop 1
        !endif
        dumstr = MR_windfiles(1)
 110    format(a50,a1,i4,a1)
        write(MR_windfiles(1),110)trim(ADJUSTL(dumstr)),'/', &
                                   MR_Comp_StartYear,'/'
        write(MR_windfiles(2),110)trim(ADJUSTL(dumstr)),'/', &
                                   MR_Comp_StartYear+1,'/'
        MR_windfile_starthour(1) = real(HS_hours_since_baseyear( &
                                    MR_Comp_StartYear,1,1,0.0_8,MR_BaseYear,MR_useLeap),kind=sp)
        MR_windfile_starthour(2) = real(HS_hours_since_baseyear( &
                                    MR_Comp_StartYear+1,1,1,0.0_8,MR_BaseYear,MR_useLeap),kind=sp)
        if  ((mod(MR_Comp_StartYear,4).eq.0)     .and.                     &
             (mod(MR_Comp_StartYear,100).ne.0).or.(mod(MR_Comp_StartYear,400).eq.0))then
          nt_fullmet = 1464     ! Leap year
        else
          nt_fullmet = 1460     ! Not a leap year
        endif
        ! Note: The nt_fullmet given above is the expected number based on a complete year.
        !       If MR_Comp_StartYear is the current year, then we will not have this many
        !       time steps available.  Double-check
        ! Getting current year
        call date_and_time(VALUES=values)
        Current_Year = values(1)
        ! Now getting the actual nt of the file; trying the hgt file
 111    format(a50,a4,i4,a3)
        write(infile,111)trim(adjustl(MR_windfiles(1))), &
                         "hgt.",MR_Comp_StartYear,".nc"
        nSTAT = nf90_open(trim(ADJUSTL(infile)),NF90_NOWRITE,ncid)
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: nf90_open: ',nf90_strerror(nSTAT)
          write(MR_global_error,*)"    Could not open file: ",trim(ADJUSTL(infile))
          write(MR_global_log  ,*)'MR ERROR: nf90_open: ',nf90_strerror(nSTAT)
          write(MR_global_error,*)'Exiting'
          stop 1
        endif
        nSTAT = nf90_inq_dimid(ncid,Met_dim_names(1),t_dim_id)
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: inq_dimid time: ',nf90_strerror(nSTAT)
          write(MR_global_error,*)"    Could not find dimension: ",Met_dim_names(1)
          write(MR_global_log  ,*)'MR ERROR: inq_dimid time: ',nf90_strerror(nSTAT)
          stop 1
        endif
        nSTAT = nf90_Inquire_Dimension(ncid,t_dim_id,len=nt_tst)
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: inq_dimid time: ',nf90_strerror(nSTAT)
          write(MR_global_error,*)"    Could not dimension length: "
          write(MR_global_log  ,*)'MR ERROR: inq_dimid time: ',nf90_strerror(nSTAT)
          stop 1
        endif
        nSTAT = nf90_close(ncid)
        if(MR_Comp_StartYear.lt.Current_Year.and.nt_tst.lt.nt_fullmet)then
          write(MR_global_info,*)"WARNING:  The NCEP files are for an archived year yet are incomplete."
          write(MR_global_info,*)"          To get the complete year, run the script "
          write(MR_global_info,*)"            autorun_scripts/get_NCEP_50YearReanalysis.sh",MR_Comp_StartYear
          write(MR_global_info,*)"          Steps available = ",nt_tst
          write(MR_global_info,*)"          Hours into year = ",(nt_tst-1)*6
        endif
        nt_fullmet = nt_tst
        MR_windfiles_nt_fullmet(1)=nt_fullmet
        MR_windfiles_nt_fullmet(2)=nt_fullmet  ! Note: we don't care if the next
                                               !       year is a leap year since
                                               !       the simulation will never
                                               !       be long enough to matter.
        allocate(MR_windfile_stephour(MR_iwindfiles,nt_fullmet))

          ! the interval for both iwf25 and iwf27 is 6 hours
        do iwstep = 1,nt_fullmet
          MR_windfile_stephour(:,iwstep) = (iwstep-1)*6.0_dp
        enddo
      elseif(MR_iwindformat.eq.31)then
        ! Here's the branch for the Catania files
        do iw = 1,MR_iwindfiles
          nSTAT = nf90_open(trim(ADJUSTL(MR_windfiles(iw))),NF90_NOWRITE,ncid)
          if(nSTAT.ne.NF90_NOERR)then
            write(MR_global_error,*)'MR ERROR: nf90_open to read header:', &
                           nf90_strerror(nSTAT)
            write(MR_global_error,*)'Could not open ',trim(ADJUSTL(MR_windfiles(iw)))
            write(MR_global_error,*)'Exiting'
            stop 1
          endif
          if(iw.eq.1)then
            nSTAT = nf90_inq_dimid(ncid,Met_dim_names(1),t_dim_id)
            if(nSTAT.ne.NF90_NOERR)then
              write(MR_global_error,*)'MR ERROR: inq_dimid time: ',nf90_strerror(nSTAT)
              write(MR_global_error,*)"    Could not find dimension: ",Met_dim_names(1)
              write(MR_global_log  ,*)'MR ERROR: inq_dimid time: ',nf90_strerror(nSTAT)
              stop 1
            endif
            nSTAT = nf90_Inquire_Dimension(ncid,t_dim_id,len=nt_fullmet)
            if(nSTAT.ne.NF90_NOERR) then
              write(MR_global_error,*)'MR ERROR: Inquire_Dimension time: ', &
                                 nf90_strerror(nSTAT)
              write(MR_global_log  ,*)'MR ERROR: Inquire_Dimension time: ', &
                                 nf90_strerror(nSTAT)
              stop 1
            endif
            allocate(filetime_in_sp(nt_fullmet))
            if(iw.eq.1)allocate(MR_windfile_stephour(MR_iwindfiles,nt_fullmet))
          endif
          MR_windfiles_nt_fullmet(iw)=nt_fullmet

          ! get id for time
          nSTAT = nf90_inq_varid(ncid,Met_dim_names(1),time_var_id)
          if(nSTAT.ne.NF90_NOERR)then
            write(MR_global_error,*)'MR ERROR: inq_varid:',"time",nf90_strerror(nSTAT)
            write(MR_global_log  ,*)'MR ERROR: inq_varid:',"time",nf90_strerror(nSTAT)
            stop 1
          endif
          ! time is an interger*4
          nSTAT = nf90_get_var(ncid,time_var_id,filetime_in_sp)
          if(nSTAT.ne.NF90_NOERR)then
            write(MR_global_error,*)'MR ERROR: get_var:',"time",nf90_strerror(nSTAT)
            write(MR_global_log  ,*)'MR ERROR: get_var:',"time",nf90_strerror(nSTAT)
            stop 1
          endif
          filetime_in_int = nint(filetime_in_sp(1))

          nSTAT = nf90_inq_varid(ncid,"reftime",reftime_var_id)
          if(nSTAT.ne.NF90_NOERR)then
            write(MR_global_error,*)'MR ERROR: inq_varid:',"reftime",nf90_strerror(nSTAT)
            write(MR_global_log  ,*)'MR ERROR: inq_varid:',"reftime",nf90_strerror(nSTAT)
            stop 1
          endif

          nSTAT = nf90_get_var(ncid,reftime_var_id,tstring)
          if(nSTAT.ne.NF90_NOERR)then
            write(MR_global_error,*)'MR ERROR: get_var:',"reftime",nf90_strerror(nSTAT)
            write(MR_global_log  ,*)'MR ERROR: get_var:',"reftime",nf90_strerror(nSTAT)
            stop 1
          endif

          read(tstring,131)itstart_year,itstart_month,itstart_day, &
                            itstart_hour,itstart_min
          itstart_sec = 0
          filestart_hour = real(itstart_hour+filetime_in_int,kind=sp) + &
                           real(itstart_min,kind=sp)/60.0_sp      + &
                           real(itstart_sec,kind=sp)/3600.0_sp
 131      format(i4,1x,i2,1x,i2,1x,i2,1x,i2)

          nSTAT = nf90_close(ncid)
          if(nSTAT.ne.NF90_NOERR)then
            write(MR_global_error,*)'MR ERROR: Could not close file',nf90_strerror(nSTAT)
            write(MR_global_log  ,*)'MR ERROR: Could not close file:',nf90_strerror(nSTAT)
            stop 1
          endif

          MR_windfile_starthour(iw) =  real(HS_hours_since_baseyear(itstart_year,itstart_month, &
                                         itstart_day,real(filestart_hour,kind=8),MR_BaseYear,MR_useLeap),kind=4)

          do iwstep = 1,nt_fullmet
            MR_windfile_stephour(iw,iwstep) = MR_windfile_stephour(iw,1) + filetime_in_sp(iwstep)
          enddo
        enddo
      elseif(MR_iwindformat.eq.50)then
        ! Branch for WRF files
        ! Loop through all the windfiles
        do iw = 1,MR_iwindfiles
          nSTAT = nf90_open(trim(ADJUSTL(MR_windfiles(iw))),NF90_NOWRITE,ncid)
          if(nSTAT.ne.NF90_NOERR)then
            write(MR_global_error,*)'MR ERROR: nf90_open to read header:', &
                           nf90_strerror(nSTAT)
            write(MR_global_error,*)'Could not open ',trim(ADJUSTL(MR_windfiles(iw)))
            write(MR_global_error,*)'Exiting'
            stop 1
          endif
          if(iw.eq.1)then
            nSTAT = nf90_inq_varid(ncid,"Times",time_var_id)
            if(nSTAT.ne.NF90_NOERR)then
              write(MR_global_error,*)'MR ERROR: inq_varid:',"Times",nf90_strerror(nSTAT)
              write(MR_global_log  ,*)'MR ERROR: inq_varid:',"Times",nf90_strerror(nSTAT)
              stop 1
            endif
            nSTAT = nf90_inquire_variable(ncid, time_var_id, invar, &
                xtype = var_xtype)
            if(nSTAT.ne.NF90_NOERR)then
              write(MR_global_error,*)'MR ERROR: inq_variable:',"Times",nf90_strerror(nSTAT)
              write(MR_global_log  ,*)'MR ERROR: inq_variable:',"Times",nf90_strerror(nSTAT)
              stop 1
            endif
            allocate(MR_windfile_stephour(MR_iwindfiles,nt_fullmet))
            allocate(filetime_in_sp(nt_fullmet))
            If(nt_fullmet.gt.1)then
              write(MR_global_error,*)"MR ERROR: Currently WRF files are expected to only have one"
              write(MR_global_error,*)"       timestep/file"
              stop 1
            endif
            filetime_in_sp = 0.0_sp
          endif
          nSTAT = nf90_get_var(ncid,time_var_id,Timestr_WRF,&
                         start = (/1,1/),       &
                         count = (/19,1/))
          if(nSTAT.ne.NF90_NOERR)then
            write(MR_global_error,*)'MR ERROR: get_var:',"Times",nf90_strerror(nSTAT)
            write(MR_global_log  ,*)'MR ERROR: get_var:',"Times",nf90_strerror(nSTAT)
            stop 1
          endif

          nSTAT = nf90_close(ncid)
          if(nSTAT.ne.NF90_NOERR)then
            write(MR_global_error,*)'MR ERROR: Could not close file',nf90_strerror(nSTAT)
            write(MR_global_log  ,*)'MR ERROR: Could not close file:',nf90_strerror(nSTAT)
            stop 1
          endif

          read(Timestr_WRF,121)itstart_year,itstart_month,itstart_day, &
                            itstart_hour,itstart_min,itstart_sec
          filestart_hour = real(itstart_hour,kind=sp) + &
                           real(itstart_min,kind=sp)/60.0_sp      + &
                           real(itstart_sec,kind=sp)/3600.0_sp
 121      format(i4,1x,i2,1x,i2,1x,i2,1x,i2,1x,i2,1x)
          MR_windfiles_nt_fullmet(iw)=nt_fullmet
          MR_windfile_starthour(iw) = real(HS_hours_since_baseyear(itstart_year,itstart_month, &
                                       itstart_day,real(filestart_hour,kind=8),MR_BaseYear,MR_useLeap),kind=4)
          do iwstep = 1,nt_fullmet
            MR_windfile_stephour(iw,iwstep) = MR_windfile_stephour(iw,1) + filetime_in_sp(iwstep)
          enddo
        enddo

      else
        ! For all other formats, try to read the GRIB_orgReferenceTime string
        ! Loop through all the windfiles
        do iw = 1,MR_iwindfiles

          ! Each wind file needs a ref-time which in almost all cases is given
          ! in the 'units' attribute of the time variable
          write(MR_global_info,*)iw,trim(ADJUSTL(MR_windfiles(iw)))
          nSTAT = nf90_open(trim(ADJUSTL(MR_windfiles(iw))),NF90_NOWRITE,ncid)
          if(nSTAT.ne.NF90_NOERR)then
            write(MR_global_error,*)'MR ERROR: nf90_open to read header:', &
                           nf90_strerror(nSTAT)
            write(MR_global_error,*)'Could not open ',trim(ADJUSTL(MR_windfiles(iw)))
            write(MR_global_error,*)'Exiting'
            stop 1
          endif
          ! Find the id of the time dimension
          nSTAT = nf90_inq_dimid(ncid,trim(ADJUSTL(Met_dim_names(1))),t_dim_id)
          if(nSTAT.ne.NF90_NOERR)then
            write(MR_global_error,*)'MR ERROR: inq_dimid time: ',nf90_strerror(nSTAT)
            write(MR_global_error,*)"    Could not find dimension: ",Met_dim_names(1)
            write(MR_global_log  ,*)'MR ERROR: inq_dimid time: ',nf90_strerror(nSTAT)
            stop 1
          endif
          if(iw.eq.1)then
            ! Get length of time dimension and allocate MR_windfile_stephour
            nSTAT = nf90_Inquire_Dimension(ncid,t_dim_id,len=nt_fullmet)
            if(nSTAT.ne.NF90_NOERR)then
              write(MR_global_error,*)'MR ERROR: Inquire_Dimension time: ', &
                                 nf90_strerror(nSTAT)
              write(MR_global_log  ,*)'MR ERROR: Inquire_Dimension time: ', &
                                 nf90_strerror(nSTAT)
              stop 1
            endif
            write(MR_global_info,*)"  Assuming all NWP files have the same number of steps."
            write(MR_global_info,*)"   Allocating time arrays for ",MR_iwindfiles,"files"
            write(MR_global_info,*)"                              ",nt_fullmet,"step(s) each"
            allocate(MR_windfile_stephour(MR_iwindfiles,nt_fullmet))
          endif

          ! get variable id for time
          nSTAT = nf90_inq_varid(ncid,trim(ADJUSTL(Met_dim_names(1))),time_var_id)
          if(nSTAT.ne.NF90_NOERR) then
            write(MR_global_error,*)'MR ERROR: inq_varid:',"time",nf90_strerror(nSTAT)
            write(MR_global_log  ,*)'MR ERROR: inq_varid:',"time",nf90_strerror(nSTAT)
            stop 1
          endif
          ! We need the reftime for this file, check time variable for 'units'
          nSTAT = nf90_Inquire_Attribute(ncid, time_var_id,&
                                         "units",xtype, length, attnum)
          if(nSTAT.eq.0)then
            TimeHasUnitsAttr = .true.
            nSTAT = nf90_get_att(ncid, time_var_id,"units",tstring2)
            if(nSTAT.ne.NF90_NOERR) then
              write(MR_global_error,*)'MR ERROR: get_att:',"time",nf90_strerror(nSTAT)
              write(MR_global_log  ,*)'MR ERROR: get_att:',"time",nf90_strerror(nSTAT)
              stop 1
            endif
          else
            ! Try GRIB_orgReferenceTime
            nSTAT = nf90_Inquire_Attribute(ncid, time_var_id,&
                                           "GRIB_orgReferenceTime",xtype, length, attnum)
            if(nSTAT.ne.NF90_NOERR) then
              write(MR_global_error,*)'MR ERROR: get_att:',"time",nf90_strerror(nSTAT)
              write(MR_global_log  ,*)'MR ERROR: get_att:',"time",nf90_strerror(nSTAT)
              stop 1
            endif
            if(nSTAT.eq.0)then
              nSTAT = nf90_get_att(ncid, time_var_id,"GRIB_orgReferenceTime",tstring2)
              if(nSTAT.ne.NF90_NOERR) then
                write(MR_global_error,*)'MR ERROR: get_att:',"time",nf90_strerror(nSTAT)
                write(MR_global_log  ,*)'MR ERROR: get_att:',"time",nf90_strerror(nSTAT)
                stop 1
              endif
              TimeHasUnitsAttr = .true.
            else
              TimeHasUnitsAttr = .false.
            endif
          endif

          if(TimeHasUnitsAttr)then
            do i=1,26
              ! try to parse
              !  time:units = "Hour since 2016-01-11T00:00:00Z" ;
              !  time:units = "days since 0001-01-01 00:00:00" ;
              if(tstring2(i:i+5).eq.'since ')then
                ii = i+6
                read(tstring2(ii:31),103)itstart_year,itstart_month,itstart_day, &
                                  itstart_hour,itstart_min,itstart_sec
                write(MR_global_info,2100)"Ref time = ",itstart_year,itstart_month,itstart_day, &
                                           itstart_hour,itstart_min,itstart_sec
                filestart_hour = real(itstart_hour,kind=sp) + &
                                 real(itstart_min,kind=sp)/60.0_sp      + &
                                 real(itstart_sec,kind=sp)/3600.0_sp
                exit
              elseif(i.eq.26)then
                ! If we got to the end of the string without finding 'since',
                ! this may be an old MERRA file
                ii = 1
                read(tstring2(ii:31),103)itstart_year,itstart_month,itstart_day,&
                                  itstart_hour,itstart_min,itstart_sec
                write(MR_global_info,2100)"Ref time = ",itstart_year,itstart_month,itstart_day, &
                                           itstart_hour,itstart_min,itstart_sec
                filestart_hour = real(itstart_hour,kind=sp) + &
                                 real(itstart_min,kind=sp)/60.0_sp      + &
                                 real(itstart_sec,kind=sp)/3600.0_sp
                exit
              endif
            enddo
          else
            ! Time variable does not have units attribute
            ! Try variable 'reftime'
            nSTAT = nf90_inq_varid(ncid,'reftime',reftime_var_id)
            if(nSTAT.ne.NF90_NOERR)then
              write(MR_global_error,*)"MR ERROR:  Could not read time:units or reftime"
              write(MR_global_error,*)"        Windfile start time is not defined."
              stop 1
            endif
            nSTAT = nf90_get_var(ncid,reftime_var_id,tstring2)
            if(nSTAT.ne.NF90_NOERR)then
              write(MR_global_error,*)"MR ERROR:  Could not read reftime"
              write(MR_global_error,*)"        Windfile start time is not defined."
              stop 1
            endif
            do i=1,30
              if(tstring2(i:i+1).eq.'20'.or.tstring2(i:i+1).eq.'19')then
                write(MR_global_info,*)"Found reference time: ",tstring2(i:31)
                read(tstring2(i:31),103)itstart_year,itstart_month,itstart_day, &
                                  itstart_hour,itstart_min,itstart_sec
                write(MR_global_info,2100)"Ref time = ",itstart_year,itstart_month,itstart_day, &
                                           itstart_hour,itstart_min,itstart_sec
                filestart_hour = real(itstart_hour,kind=sp) + &
                                 real(itstart_min,kind=sp)/60.0_sp      + &
                                 real(itstart_sec,kind=sp)/3600.0_sp
                exit
              endif
            enddo
          endif
2100      format(20x,a11,i4,1x,i2,1x,i2,1x,i2,1x,i2,1x,i2)
 103      format(i4,1x,i2,1x,i2,1x,i2,1x,i2,1x,i2)

          ! Assume we now have the parsed reftime

          ! Now get time data
          ! Check if we need to read into an int, float or a double
          !nSTAT = nf90_inquire_variable(ncid, time_var_id, invar, xtype = var_xtype)
          nSTAT = nf90_inquire_variable(ncid, time_var_id, name = invar, xtype = var_xtype)
          if(nSTAT.ne.NF90_NOERR)then
            write(MR_global_error,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
            write(MR_global_log  ,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
            stop 1
          endif
          if(var_xtype.eq.NF90_FLOAT)then
            allocate(dum1d_sp(nt_fullmet))
            nSTAT = nf90_get_var(ncid,time_var_id,dum1d_sp, &
                   start = (/1/),count = (/nt_fullmet/))
            if(nSTAT.ne.NF90_NOERR)then
              write(MR_global_error,*)'MR ERROR: get_var ',Met_dim_names(1),nf90_strerror(nSTAT)
              write(MR_global_log  ,*)'MR ERROR: get_var ',Met_dim_names(1),nf90_strerror(nSTAT)
              stop 1
            endif
            ! copy to local variable
            MR_windfile_stephour(iw,1:nt_fullmet) = dum1d_sp(1:nt_fullmet)* &
                                                         Met_dim_fac(1)
            deallocate(dum1d_sp)
          elseif(var_xtype.eq.NF90_DOUBLE)then
            allocate(dum1d_dp(nt_fullmet))
            nSTAT = nf90_get_var(ncid,time_var_id,dum1d_dp, &
                   start = (/1/),count = (/nt_fullmet/))
            if(nSTAT.ne.NF90_NOERR)then
              write(MR_global_error,*)'MR ERROR: get_var ',Met_dim_names(1),nf90_strerror(nSTAT)
              write(MR_global_log  ,*)'MR ERROR: get_var ',Met_dim_names(1),nf90_strerror(nSTAT)
              stop 1
            endif
            ! copy to local variable
            MR_windfile_stephour(iw,1:nt_fullmet) = real(dum1d_dp(1:nt_fullmet),kind=4)* &
                                                         Met_dim_fac(1)
            deallocate(dum1d_dp)
          elseif(var_xtype.eq.NF90_INT)then
            allocate(dum1d_int4(nt_fullmet))
            nSTAT = nf90_get_var(ncid,time_var_id,dum1d_int4, &
                   start = (/1/),count = (/nt_fullmet/))
            if(nSTAT.ne.NF90_NOERR)then
              write(MR_global_error,*)'MR ERROR: get_var ',Met_dim_names(1),nf90_strerror(nSTAT)
              write(MR_global_log  ,*)'MR ERROR: get_var ',Met_dim_names(1),nf90_strerror(nSTAT)
              stop 1
            endif
            ! copy to local variable
            MR_windfile_stephour(iw,1:nt_fullmet) = real(dum1d_int4(1:nt_fullmet),kind=4)* &
                                                         Met_dim_fac(1)
            deallocate(dum1d_int4)
          else
            write(MR_global_error,*)"MR ERROR: Unexpected time variable type ",Met_dim_names(i)
            stop 1
          endif

          nSTAT = nf90_close(ncid)
          if(nSTAT.ne.NF90_NOERR)then
            write(MR_global_error,*)'MR ERROR: Could not close file',nf90_strerror(nSTAT)
            write(MR_global_log  ,*)'MR ERROR: Could not close file:',nf90_strerror(nSTAT)
            stop 1
          endif

          MR_windfiles_nt_fullmet(iw) = nt_fullmet
          MR_windfile_starthour(iw) =  real(HS_hours_since_baseyear(itstart_year,itstart_month, &
                                         itstart_day,real(filestart_hour,kind=8),MR_BaseYear,MR_useLeap),kind=4)
        enddo
      endif
      ! Finished setting up the start time of each wind file in HoursSince : MR_windfile_starthour(iw)
      !  and the forecast (offset from start of file) for each step        : MR_windfile_stephour(iw,iwstep)

      if (MR_iwindformat.ne.25.and.MR_iwindformat.ne.27)then
        write(MR_global_info,*)"File, step, Ref, Offset, HoursSince"
        do iw = 1,MR_iwindfiles
          do iws = 1,nt_fullmet
            write(MR_global_info,*)iw,iws,real(MR_windfile_starthour(iw),kind=4),&
                             real(MR_windfile_stephour(iw,iws),kind=4),&
                             real(MR_windfile_starthour(iw)+MR_windfile_stephour(iw,iws),kind=4)
          enddo
        enddo
      endif

      write(MR_global_production,*)"--------------------------------------------------------------------------------"

      end subroutine MR_Read_Met_Times_netcdf
!##############################################################################

!##############################################################################
!
!     MR_Set_Met_Dims_Template_netcdf
!
!     Called from MR_Set_MetComp_Grids_netcdf
!
!     Sets Met grid for Template windfiles
!
!##############################################################################


      subroutine MR_Set_Met_Dims_Template_netcdf

      use MetReader
      use netcdf

      use projection

      implicit none

      integer, parameter :: sp        = 4 ! single precision
      integer, parameter :: dp        = 8 ! double precision
      real(kind=sp), parameter :: tol = 1.0e-7_sp

      integer :: iw,pi,i

      integer :: nSTAT
      integer :: ncid

      integer            :: var_xtype
      integer            :: xtype, length, attnum
      character(len=40)  :: invar
      character(len = nf90_max_name) :: name_dum
      integer :: t_dim_id,x_dim_id,y_dim_id,z_dim_id
      integer :: var_id
      real(kind=dp),dimension(:), allocatable :: dum1d_dp
      real(kind=sp),dimension(:), allocatable :: dum1d_sp
      real(kind=sp):: dum_sp
      logical :: TimeHasFillVAttr

      write(MR_global_production,*)"--------------------------------------------------------------------------------"
      write(MR_global_production,*)"----------                MR_Set_Met_Dims_Template_netcdf             ----------"
      write(MR_global_production,*)"--------------------------------------------------------------------------------"

      ! To set up the grid, we assume that the grid is the same for all
      ! windfiles.  There is no checking if this is actually the case.
      ! Just read the first windfile.
      iw = 1
      write(MR_global_info,*)"Opening ",iw,trim(ADJUSTL(MR_windfiles(iw)))
      nSTAT = nf90_open(trim(ADJUSTL(MR_windfiles(iw))),NF90_NOWRITE,ncid)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: nf90_open to read header:', nf90_strerror(nSTAT)
        write(MR_global_error,*)'Could not open ',trim(ADJUSTL(MR_windfiles(iw)))
        write(MR_global_error,*)'Exiting'
        stop 1
      else
        write(MR_global_info,*)"Opened ",trim(ADJUSTL(MR_windfiles(iw)))
      endif

      ! Get dim ids, sizes, and associated dimension variable for dims:
      !  1 = time
      !  2 = pressure used for state variables
      !  3 = y or lat
      !  4 = x or lon
      !  5 = pressure used for Vz
      !  6 = pressure uesed for RH or SH
      !  7 = height above ground
      !  8 = depth below surface
      !  9 = extra pressure dimension

      ! Time
      !  This will be repeated in MR_Set_Met_Times_netcdf where the time values
      !  are read, but for now, we just want the dimension size
      i = 1
      if(.not.Met_dim_IsAvailable(i))then
        write(MR_global_error,*)"MR ERROR: TIME dimension is required and not listed"
        write(MR_global_error,*)"          in template windfile specification file."
        stop 1
      endif
      nSTAT = nf90_inq_dimid(ncid,Met_dim_names(i),t_dim_id)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: inq_dimid ',Met_dim_names(i),nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: inq_dimid ',Met_dim_names(i),nf90_strerror(nSTAT)
        stop 1
      endif
      nSTAT = nf90_Inquire_Dimension(ncid,t_dim_id,name=name_dum,len=nt_fullmet)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: Inquire_Dimension ',Met_dim_names(i),nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: Inquire_Dimension ',Met_dim_names(i),nf90_strerror(nSTAT)
        stop 1
      endif

      ! X (or lon)
      i = 4
      if(.not.Met_dim_IsAvailable(i))then
        write(MR_global_error,*)"MR ERROR: X/LON dimension is required and not listed"
        write(MR_global_error,*)"          in template windfile specification file."
        stop 1
      endif
      nSTAT = nf90_inq_dimid(ncid,Met_dim_names(i),x_dim_id)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: inq_dimid ',Met_dim_names(i),nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: inq_dimid ',Met_dim_names(i),nf90_strerror(nSTAT)
        stop 1
      endif
      nSTAT = nf90_Inquire_Dimension(ncid,x_dim_id,name=name_dum,len=nx_fullmet)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: Inquire_Dimension ',Met_dim_names(i),nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: Inquire_Dimension ',Met_dim_names(i),nf90_strerror(nSTAT)
        stop 1
      endif
      nSTAT = nf90_inq_varid(ncid,Met_dim_names(i),var_id)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: inq_varid ',Met_dim_names(i),nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: inq_varid ',Met_dim_names(i),nf90_strerror(nSTAT)
        stop 1
      endif
      ! Check if we need to read into a float or a double
      nSTAT = nf90_inquire_variable(ncid, var_id, invar, xtype = var_xtype)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
        stop 1
      endif
      allocate(x_fullmet_sp(nx_fullmet))
      allocate(MR_dx_met(nx_fullmet))
      if(var_xtype.eq.NF90_FLOAT)then
        allocate(dum1d_sp(nx_fullmet))
        nSTAT = nf90_get_var(ncid,var_id,dum1d_sp, &
               start = (/1/),count = (/nx_fullmet/))
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: get_var ',Met_dim_names(i),nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: get_var ',Met_dim_names(i),nf90_strerror(nSTAT)
          stop 1
        endif
        ! copy to local variable
        x_fullmet_sp(:) = dum1d_sp(:)
        deallocate(dum1d_sp)
      elseif(var_xtype.eq.NF90_DOUBLE)then
        allocate(dum1d_dp(nx_fullmet))
        nSTAT = nf90_get_var(ncid,var_id,dum1d_dp, &
               start = (/1/),count = (/nx_fullmet/))
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: get_var ',Met_dim_names(i),nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: get_var ',Met_dim_names(i),nf90_strerror(nSTAT)
          stop 1
        endif
        ! copy to local variable
        x_fullmet_sp(:) = real(dum1d_dp(:),kind=4)
        deallocate(dum1d_dp)
      else
        write(MR_global_error,*)"MR ERROR: Unexpected dim variable type ",Met_dim_names(i)
        stop 1
      endif

      ! km or degrees is expected; apply the conversion factor
      x_fullmet_sp(:) = x_fullmet_sp(:)*Met_dim_fac(i)

      ! If the coordinate is decreasing, leave as is, but make a note
      dx_met_const = x_fullmet_sp(2) - x_fullmet_sp(1)
      if(dx_met_const.lt.0.0_sp)then
        x_inverted = .true.
        dx_met_const = abs(dx_met_const)
      else
        x_inverted = .false.
      endif
      do i = 1,nx_fullmet-1
        MR_dx_met(i) = x_fullmet_sp(i+1)-x_fullmet_sp(i)
      enddo
      MR_dx_met(nx_fullmet) = MR_dx_met(nx_fullmet-1)

      ! Y (or lat)
      i = 3
      if(.not.Met_dim_IsAvailable(i))then
        write(MR_global_error,*)"MR ERROR: Y/LAT dimension is required and not listed"
        write(MR_global_error,*)"       in template windfile specification file."
        stop 1
      endif
      nSTAT = nf90_inq_dimid(ncid,Met_dim_names(i),y_dim_id)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: inq_dimid ',Met_dim_names(i),nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: inq_dimid ',Met_dim_names(i),nf90_strerror(nSTAT)
        stop 1
      endif
      nSTAT = nf90_Inquire_Dimension(ncid,y_dim_id,name=name_dum,len=ny_fullmet)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: Inquire_Dimension ',Met_dim_names(i),nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: Inquire_Dimension ',Met_dim_names(i),nf90_strerror(nSTAT)
        stop 1
      endif
      nSTAT = nf90_inq_varid(ncid,Met_dim_names(i),var_id)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: inq_varid ',Met_dim_names(i),nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: inq_varid ',Met_dim_names(i),nf90_strerror(nSTAT)
        stop 1
      endif
      ! Check if we need to read into a float or a double
      nSTAT = nf90_inquire_variable(ncid, var_id, invar, xtype = var_xtype)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
        stop 1
      endif
      allocate(y_fullmet_sp(ny_fullmet))
      allocate(MR_dy_met(ny_fullmet))
      if(var_xtype.eq.NF90_FLOAT)then
        allocate(dum1d_sp(ny_fullmet))
        nSTAT = nf90_get_var(ncid,var_id,dum1d_sp, &
               start = (/1/),count = (/ny_fullmet/))
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: get_var ',Met_dim_names(i),nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: get_var ',Met_dim_names(i),nf90_strerror(nSTAT)
          stop 1
        endif
        ! copy to local variable
        y_fullmet_sp(:) = dum1d_sp(:)
        deallocate(dum1d_sp)
      elseif(var_xtype.eq.NF90_DOUBLE)then
        allocate(dum1d_dp(ny_fullmet))
        nSTAT = nf90_get_var(ncid,var_id,dum1d_dp, &
               start = (/1/),count = (/ny_fullmet/))
        if(nSTAT.ne.NF90_NOERR)then
          write(MR_global_error,*)'MR ERROR: get_var ',Met_dim_names(i),nf90_strerror(nSTAT)
          write(MR_global_log  ,*)'MR ERROR: get_var ',Met_dim_names(i),nf90_strerror(nSTAT)
          stop 1
        endif
        ! copy to local variable
        y_fullmet_sp(:) = real(dum1d_dp(:),kind=4)
        deallocate(dum1d_dp)
      else
        write(MR_global_error,*)"MR ERROR: Unexpected dim variable type ",Met_dim_names(i)
        stop 1
      endif
      ! km or degrees is expected; apply the conversion factor
      y_fullmet_sp(:) = y_fullmet_sp(:)*Met_dim_fac(i)
      ! If the coordinate is decreasing, leave as is, but make a note
      dy_met_const = y_fullmet_sp(2) - y_fullmet_sp(1)
      if(dy_met_const.lt.0.0_sp)then
        y_inverted = .true.
        dy_met_const = abs(dy_met_const)
      else
        y_inverted = .false.
      endif
      do i = 1,ny_fullmet-1
        MR_dy_met(i) = y_fullmet_sp(i+1)-y_fullmet_sp(i)
      enddo
      MR_dy_met(ny_fullmet)    = MR_dy_met(ny_fullmet-1)

      ! We need to check if this is a regular grid
      IsRegular_MetGrid = .true.
      do i = 1,nx_fullmet-1
        if(abs(MR_dx_met(i+1)-MR_dx_met(i)).gt.tol*MR_dx_met(i))then
          IsRegular_MetGrid = .false.
        endif
      enddo
      do i = 1,ny_fullmet-1
        if(abs(MR_dy_met(i+1)-MR_dy_met(i)).gt.tol*MR_dy_met(i))then
          IsRegular_MetGrid = .false.
        endif
      enddo

      ! P 
      !i = 2
      !if(.not.Met_dim_IsAvailable(i))then
      !  write(MR_global_error,*)"MR ERROR: Pressure dimension is required and not listed"
      !  write(MR_global_error,*)"       in template windfile specification file."
      !  stop 1
      !endif
      !nSTAT = nf90_inq_dimid(ncid,Met_dim_names(i),z_dim_id)
      !if(nSTAT.ne.NF90_NOERR)then
      !  write(MR_global_error,*)'MR ERROR: inq_dimid ',Met_dim_names(i),nf90_strerror(nSTAT)
      !  write(MR_global_log  ,*)'MR ERROR: inq_dimid ',Met_dim_names(i),nf90_strerror(nSTAT)
      !  stop 1
      !endif
      !nSTAT = nf90_Inquire_Dimension(ncid,z_dim_id,name=name_dum,len=np_fullmet)
      !if(nSTAT.ne.NF90_NOERR)then
      !  write(MR_global_error,*)'MR ERROR: Inquire_Dimension ',Met_dim_names(i),nf90_strerror(nSTAT)
      !  write(MR_global_log  ,*)'MR ERROR: Inquire_Dimension ',Met_dim_names(i),nf90_strerror(nSTAT)
      !  stop 1
      !endif
      !nSTAT = nf90_inq_varid(ncid,Met_dim_names(i),var_id)
      !if(nSTAT.ne.NF90_NOERR)then
      !  write(MR_global_error,*)'MR ERROR: inq_varid ',Met_dim_names(i),nf90_strerror(nSTAT)
      !  write(MR_global_log  ,*)'MR ERROR: inq_varid ',Met_dim_names(i),nf90_strerror(nSTAT)
      !  stop 1
      !endif
      !! Check if we need to read into a float or a double
      !nSTAT = nf90_inquire_variable(ncid, var_id, invar, xtype = var_xtype)
      !if(nSTAT.ne.NF90_NOERR)then
      !  write(MR_global_error,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
      !  write(MR_global_log  ,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
      !  stop 1
      !endif
      !allocate(p_fullmet_sp(np_fullmet))
      !if(var_xtype.eq.NF90_FLOAT)then
      !  allocate(dum1d_sp(np_fullmet))
      !  nSTAT = nf90_get_var(ncid,var_id,dum1d_sp, &
      !         start = (/1/),count = (/np_fullmet/))
      !  if(nSTAT.ne.NF90_NOERR)then
      !    write(MR_global_error,*)'MR ERROR: get_var ',Met_dim_names(i),nf90_strerror(nSTAT)
      !    write(MR_global_log  ,*)'MR ERROR: get_var ',Met_dim_names(i),nf90_strerror(nSTAT)
      !    stop 1
      !  endif
      !  ! copy to local variable
      !  p_fullmet_sp(:) = dum1d_sp(:)
      !  deallocate(dum1d_sp)
      !elseif(var_xtype.eq.NF90_DOUBLE)then
      !  allocate(dum1d_dp(np_fullmet))
      !  nSTAT = nf90_get_var(ncid,var_id,dum1d_dp, &
      !         start = (/1/),count = (/np_fullmet/))
      !  if(nSTAT.ne.NF90_NOERR)then
      !    write(MR_global_error,*)'MR ERROR: get_var ',Met_dim_names(i),nf90_strerror(nSTAT)
      !    write(MR_global_log  ,*)'MR ERROR: get_var ',Met_dim_names(i),nf90_strerror(nSTAT)
      !    stop 1
      !  endif
      !  ! copy to local variable
      !  p_fullmet_sp(:) = real(dum1d_dp(:),kind=4)
      !  deallocate(dum1d_dp)
      !else
      !  write(MR_global_error,*)"MR ERROR: Unexpected dim variable type ",Met_dim_names(i)
      !  stop 1
      !endif
      !! If the p-coordinate is top-down (low-pressure to high), then flip the
      !! coordinate and make a note
      !if(p_fullmet_sp(1).lt.p_fullmet_sp(2))then
      !  z_inverted = .true.
      !  allocate(dum1d_sp(np_fullmet))
      !  do pi = 1,np_fullmet
      !    dum1d_sp(pi) = p_fullmet_sp(np_fullmet+1-pi)
      !  enddo
      !  p_fullmet_sp(:) = dum1d_sp(:)
      !  deallocate(dum1d_sp)
      !else
      !  z_inverted = .false.
      !endif
      !! Pa is expected; apply the conversion factor
      !p_fullmet_sp(:) = p_fullmet_sp(:)*Met_dim_fac(i)
      !MR_Max_geoH_metP_predicted = MR_Z_US_StdAtm(p_fullmet_sp(np_fullmet)) 

      !! P for Vz
      !i = 5
      !if(.not.Met_dim_IsAvailable(i))then
      !  write(MR_global_error,*)"MR ERROR: Pressure dimension is required and not listed"
      !  write(MR_global_error,*)"       in template windfile specification file."
      !  stop 1
      !endif
      !nSTAT = nf90_inq_dimid(ncid,Met_dim_names(i),z_dim_id)
      !if(nSTAT.ne.NF90_NOERR)then
      !  write(MR_global_error,*)'MR ERROR: inq_dimid ',Met_dim_names(i),nf90_strerror(nSTAT)
      !  write(MR_global_log  ,*)'MR ERROR: inq_dimid ',Met_dim_names(i),nf90_strerror(nSTAT)
      !  stop 1
      !endif
      !nSTAT = nf90_Inquire_Dimension(ncid,z_dim_id,name=name_dum,len=np_fullmet_Vz)
      !if(nSTAT.ne.NF90_NOERR)then
      !  write(MR_global_error,*)'MR ERROR: Inquire_Dimension ',Met_dim_names(i),nf90_strerror(nSTAT)
      !  write(MR_global_log  ,*)'MR ERROR: Inquire_Dimension ',Met_dim_names(i),nf90_strerror(nSTAT)
      !  stop 1
      !endif
      !nSTAT = nf90_inq_varid(ncid,Met_dim_names(i),var_id)
      !if(nSTAT.ne.NF90_NOERR)then
      !  write(MR_global_error,*)'MR ERROR: inq_varid ',Met_dim_names(i),nf90_strerror(nSTAT)
      !  write(MR_global_log  ,*)'MR ERROR: inq_varid ',Met_dim_names(i),nf90_strerror(nSTAT)
      !  stop 1
      !endif
      !! Check if we need to read into a float or a double
      !nSTAT = nf90_inquire_variable(ncid, var_id, invar, xtype = var_xtype)
      !if(nSTAT.ne.NF90_NOERR)then
      !  write(MR_global_error,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
      !  write(MR_global_log  ,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
      !  stop 1
      !endif
      !allocate(p_fullmet_Vz_sp(np_fullmet_Vz))
      !if(var_xtype.eq.NF90_FLOAT)then
      !  allocate(dum1d_sp(np_fullmet_Vz))
      !  nSTAT = nf90_get_var(ncid,var_id,dum1d_sp, &
      !         start = (/1/),count = (/np_fullmet_Vz/))
      !  if(nSTAT.ne.NF90_NOERR)then
      !    write(MR_global_error,*)'MR ERROR: get_var ',Met_dim_names(i),nf90_strerror(nSTAT)
      !    write(MR_global_log  ,*)'MR ERROR: get_var ',Met_dim_names(i),nf90_strerror(nSTAT)
      !    stop 1
      !  endif
      !  ! copy to local variable
      !  p_fullmet_Vz_sp(:) = dum1d_sp(:)
      !  deallocate(dum1d_sp)
      !elseif(var_xtype.eq.NF90_DOUBLE)then
      !  allocate(dum1d_dp(np_fullmet_Vz))
      !  nSTAT = nf90_get_var(ncid,var_id,dum1d_dp, &
      !         start = (/1/),count = (/np_fullmet_Vz/))
      !  if(nSTAT.ne.NF90_NOERR)then
      !    write(MR_global_error,*)'MR ERROR: get_var ',Met_dim_names(i),nf90_strerror(nSTAT)
      !    write(MR_global_log  ,*)'MR ERROR: get_var ',Met_dim_names(i),nf90_strerror(nSTAT)
      !    stop 1
      !  endif
      !  ! copy to local variable
      !  p_fullmet_Vz_sp(:) = real(dum1d_dp(:),kind=4)
      !  deallocate(dum1d_dp)
      !else
      !  write(MR_global_error,*)"MR ERROR: Unexpected dim variable type ",Met_dim_names(i)
      !  stop 1
      !endif
      !! If the p-coordinate is top-down (low-pressure to high), then flip the
      !! coordinate and make a note
      !if(p_fullmet_Vz_sp(1).lt.p_fullmet_Vz_sp(2))then
      !  allocate(dum1d_sp(np_fullmet_Vz))
      !  do pi = 1,np_fullmet_Vz
      !    dum1d_sp(pi) = p_fullmet_Vz_sp(np_fullmet_Vz+1-pi)
      !  enddo
      !  p_fullmet_Vz_sp(:) = dum1d_sp(:)
      !  deallocate(dum1d_sp)
      !endif
      !! Pa is expected; apply the conversion factor
      !p_fullmet_Vz_sp(:) = p_fullmet_Vz_sp(:)*Met_dim_fac(i)

      !! P for RH
      !i = 6
      !if(.not.Met_dim_IsAvailable(i))then
      !  write(MR_global_error,*)"MR ERROR: Pressure dimension is required and not listed"
      !  write(MR_global_error,*)"          in template windfile specification file."
      !  stop 1
      !endif
      !nSTAT = nf90_inq_dimid(ncid,Met_dim_names(i),z_dim_id)
      !if(nSTAT.ne.NF90_NOERR)then
      !  write(MR_global_error,*)'MR ERROR: inq_dimid ',Met_dim_names(i),nf90_strerror(nSTAT)
      !  write(MR_global_log  ,*)'MR ERROR: inq_dimid ',Met_dim_names(i),nf90_strerror(nSTAT)
      !  stop 1
      !endif
      !nSTAT = nf90_Inquire_Dimension(ncid,z_dim_id,name=name_dum,len=np_fullmet_RH)
      !if(nSTAT.ne.NF90_NOERR)then
      !  write(MR_global_error,*)'MR ERROR: Inquire_Dimension ',Met_dim_names(i),nf90_strerror(nSTAT)
      !  write(MR_global_log  ,*)'MR ERROR: Inquire_Dimension ',Met_dim_names(i),nf90_strerror(nSTAT)
      !  stop 1
      !endif
      !nSTAT = nf90_inq_varid(ncid,Met_dim_names(i),var_id)
      !if(nSTAT.ne.NF90_NOERR)then
      !  write(MR_global_error,*)'MR ERROR: inq_varid ',Met_dim_names(i),nf90_strerror(nSTAT)
      !  write(MR_global_log  ,*)'MR ERROR: inq_varid ',Met_dim_names(i),nf90_strerror(nSTAT)
      !  stop 1
      !endif
      !! Check if we need to read into a float or a double
      !nSTAT = nf90_inquire_variable(ncid, var_id, invar, xtype = var_xtype)
      !if(nSTAT.ne.NF90_NOERR)then
      !  write(MR_global_error,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
      !  write(MR_global_log  ,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
      !  stop 1
      !endif
      !allocate(p_fullmet_RH_sp(np_fullmet_RH))
      !if(var_xtype.eq.NF90_FLOAT)then
      !  allocate(dum1d_sp(np_fullmet_RH))
      !  nSTAT = nf90_get_var(ncid,var_id,dum1d_sp, &
      !         start = (/1/),count = (/np_fullmet_RH/))
      !  if(nSTAT.ne.NF90_NOERR)then
      !    write(MR_global_error,*)'MR ERROR: get_var ',Met_dim_names(i),nf90_strerror(nSTAT)
      !    write(MR_global_log  ,*)'MR ERROR: get_var ',Met_dim_names(i),nf90_strerror(nSTAT)
      !    stop 1
      !  endif
      !  ! copy to local variable
      !  p_fullmet_RH_sp(:) = dum1d_sp(:)
      !  deallocate(dum1d_sp)
      !elseif(var_xtype.eq.NF90_DOUBLE)then
      !  allocate(dum1d_dp(np_fullmet_RH))
      !  nSTAT = nf90_get_var(ncid,var_id,dum1d_dp, &
      !         start = (/1/),count = (/np_fullmet_RH/))
      !  if(nSTAT.ne.NF90_NOERR)then
      !    write(MR_global_error,*)'MR ERROR: get_var ',Met_dim_names(i),nf90_strerror(nSTAT)
      !    write(MR_global_log  ,*)'MR ERROR: get_var ',Met_dim_names(i),nf90_strerror(nSTAT)
      !    stop 1
      !  endif
      !  ! copy to local variable
      !  p_fullmet_RH_sp(:) = real(dum1d_dp(:),kind=4)
      !  deallocate(dum1d_dp)
      !else
      !  write(MR_global_error,*)"MR ERROR: Unexpected dim variable type ",Met_dim_names(i)
      !  stop 1
      !endif
      !! If the p-coordinate is top-down (low-pressure to high), then flip the
      !! coordinate and make a note
      !if(p_fullmet_RH_sp(1).lt.p_fullmet_RH_sp(2))then
      !  allocate(dum1d_sp(np_fullmet_RH))
      !  do pi = 1,np_fullmet_RH
      !    dum1d_sp(pi) = p_fullmet_RH_sp(np_fullmet_RH+1-pi)
      !  enddo
      !  p_fullmet_RH_sp(:) = dum1d_sp(:)
      !  deallocate(dum1d_sp)
      !endif
      !! Pa is expected; apply the conversion factor
      !p_fullmet_RH_sp(:) = p_fullmet_RH_sp(:)*Met_dim_fac(i)

      ! Need to get fill_value
      ! Try to get it from geopotential height variable
      nSTAT = nf90_inq_varid(ncid,Met_var_names(1),var_id)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: inq_varid: ',invar,nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: inq_varid: ',invar,nf90_strerror(nSTAT)
        stop 1
      endif
      nSTAT = nf90_Inquire_Attribute(ncid, var_id,&
                                     "_FillValue",xtype, length, attnum)
      if(nSTAT.eq.0)then
        TimeHasFillVAttr = .true.
      else
        TimeHasFillVAttr = .false.
      endif
      if(TimeHasFillVAttr)then
        nSTAT = nf90_get_att(ncid, var_id,"_FillValue",dum_sp)
        fill_value_sp(MR_iwindformat) = dum_sp
        write(MR_global_info,*)"    Found fill value",fill_value_sp(MR_iwindformat)
      else
        fill_value_sp(MR_iwindformat) = -9999.0_sp
      endif

      nSTAT = nf90_close(ncid)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: Could not close file',nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: Could not close file:',nf90_strerror(nSTAT)
        stop 1
      endif

      end subroutine MR_Set_Met_Dims_Template_netcdf

!##############################################################################
!
!     MR_Read_MetP_Variable_netcdf
!
!     Called from Read_HGT_arrays and once from Read_3d_MetP_Variable.
!
!     Sets MR_dum3d_metP, MR_dum2d_met, or MR_dum2d_met_int as appropriate
!
!##############################################################################

      subroutine MR_Read_MetP_Variable_netcdf(ivar,istep)

      use MetReader
      use netcdf

      implicit none

      integer, parameter :: sp        = 4 ! single precision
      integer, parameter :: dp        = 8 ! double precision

      integer,intent(in) :: ivar
      integer,intent(in) :: istep

      integer :: iw,iwstep
      integer :: np_met_loc
      character(len=130) :: infile
      character(len=71)  :: invar

      integer :: ncid       = 0
      integer :: nSTAT      = 0
      integer :: in_var_id  = 0
      integer :: in_var_id1 = 0
      integer :: in_var_id2 = 0

      real(kind=sp) :: del_H,del_P,dpdz

      integer :: i,j,k,ii,jj,kk,kkk,itmp
      integer :: ict, ileft(2),iright(2)   !if wrapgrid=.true. ict=2 and left & iright have 2 values, otherwise 1
      integer :: iistart(2),iicount(2)     !if (wrapgrid), iistart(1)=istart, iistart(2)=1

      integer :: Dimension_of_Variable
      logical :: IsCatagorical

      integer :: var_xtype
      integer :: NC_version

      real(kind=sp),dimension(:,:,:,:),allocatable :: dum3d_metP_aux
      real(kind=sp) :: theta,cofac

      real(kind=sp) :: Z_top, T_top
      real(kind=sp) :: pp
      integer       :: idx

      if(.not.Met_var_IsAvailable(ivar))then
        write(MR_global_error,*)"MR ERROR:  Variable not available for this windfile"
        write(MR_global_error,*)"             ivar = ",ivar
        write(MR_global_error,*)"            vname = ",Met_var_names(ivar)
        write(MR_global_error,*)"             iwf  = ",MR_iwindformat
        stop 1
      endif

      iw     = MR_MetStep_findex(istep)
      iwstep = MR_MetStep_tindex(istep)

      if(Met_var_names(ivar).eq."")then
        write(MR_global_info,*)"Variable ",ivar," not available for MR_iwindformat = ",&
                  MR_iwindformat
        stop 1
      endif

      ! Get the dimension of the variable requested (either 2 or 3-D)
      if(ivar.eq.1 ) Dimension_of_Variable = 3 ! Geopotential Height
      if(ivar.eq.2 ) Dimension_of_Variable = 3 ! Vx
      if(ivar.eq.3 ) Dimension_of_Variable = 3 ! Vy
      if(ivar.eq.4 ) Dimension_of_Variable = 3 ! Vz
      if(ivar.eq.5 ) Dimension_of_Variable = 3 ! Temperature
      if(ivar.eq.6 ) Dimension_of_Variable = 3 ! Pressure (only for WRF or other eta-level files)

      if(ivar.eq.10) Dimension_of_Variable = 2 ! Planetary Boundary Layer Height
      if(ivar.eq.11) Dimension_of_Variable = 2 ! U @ 10m
      if(ivar.eq.12) Dimension_of_Variable = 2 ! V @ 10m
      if(ivar.eq.13) Dimension_of_Variable = 2 ! Friction velocity
      if(ivar.eq.14) Dimension_of_Variable = 2 ! Displacement Height
      if(ivar.eq.15) Dimension_of_Variable = 2 ! Snow cover
      if(ivar.eq.16) Dimension_of_Variable = 2 ! Soil moisture
      if(ivar.eq.17) Dimension_of_Variable = 2 ! Surface roughness
      if(ivar.eq.18) Dimension_of_Variable = 2 ! Wind_speed_gust_surface

      if(ivar.eq.20) Dimension_of_Variable = 2 ! pressure at lower cloud base
      if(ivar.eq.21) Dimension_of_Variable = 2 ! pressure at lower cloud top
      if(ivar.eq.22) Dimension_of_Variable = 2 ! temperature at lower cloud top
      if(ivar.eq.23) Dimension_of_Variable = 2 ! Total Cloud cover
      if(ivar.eq.24) Dimension_of_Variable = 2 ! Cloud cover (low)
      if(ivar.eq.25) Dimension_of_Variable = 2 ! Cloud cover (convective)

      if(ivar.eq.30) Dimension_of_Variable = 3 ! Rel. Hum
      if(ivar.eq.31) Dimension_of_Variable = 3 ! QV (specific humidity)
      if(ivar.eq.32) Dimension_of_Variable = 3 ! QL (liquid)
      if(ivar.eq.33) Dimension_of_Variable = 3 ! QI (ice)

      if(ivar.eq.40) Dimension_of_Variable = 2 ! Categorical rain
      if(ivar.eq.41) Dimension_of_Variable = 2 ! Categorical snow
      if(ivar.eq.42) Dimension_of_Variable = 2 ! Categorical frozen rain
      if(ivar.eq.43) Dimension_of_Variable = 2 ! Categorical ice
      if(MR_iwindformat.eq.24)then
          ! NASA MERRA has 3d precipitation
        if(ivar.eq.44) Dimension_of_Variable = 3 ! Precipitation rate large-scale (liquid)
        if(ivar.eq.45) Dimension_of_Variable = 3 ! Precipitation rate convective (liquid)
      else
          ! All other met files use surface precip
        if(ivar.eq.44) Dimension_of_Variable = 2 ! Precipitation rate large-scale (liquid)
        if(ivar.eq.45) Dimension_of_Variable = 2 ! Precipitation rate convective (liquid)
      endif
      if(ivar.eq.46) Dimension_of_Variable = 3 ! Precipitation rate large-scale (ice)
      if(ivar.eq.47) Dimension_of_Variable = 3 ! Precipitation rate convective (ice)

      if(ivar.eq.40.or.&
         ivar.eq.41.or.&
         ivar.eq.42.or.&
         ivar.eq.43)then
          ! Catagorical variables are integers and need special interpolation
        IsCatagorical = .true.
      else
          ! The default is to read floating point values
        IsCatagorical = .false.
      endif

      if(MR_iwindformat.eq.25)then
        ! Get correct file
        if(ivar.eq.1)then
          write(infile,115)trim(adjustl(MR_MetStep_File(istep))), &
                           "hgt.",MR_iwind5_year(istep),".nc"
          np_met_loc = np_fullmet
        elseif(ivar.eq.2)then
          write(infile,116)trim(adjustl(MR_MetStep_File(istep))), &
                           "uwnd.",MR_iwind5_year(istep),".nc"
          np_met_loc = np_fullmet
        elseif(ivar.eq.3)then
          write(infile,116)trim(adjustl(MR_MetStep_File(istep))), &
                           "vwnd.",MR_iwind5_year(istep),".nc"
          np_met_loc = np_fullmet
        elseif(ivar.eq.4)then
          write(infile,117)trim(adjustl(MR_MetStep_File(istep))), &
                           "omega.",MR_iwind5_year(istep),".nc"
          !np_met_loc = np_fullmet_Vz
          np_met_loc = nlevs_fullmet(Met_var_zdim_idx(ivar))
        elseif(ivar.eq.5)then
          write(infile,115)trim(adjustl(MR_MetStep_File(istep))), &
                           "air.",MR_iwind5_year(istep),".nc"
          np_met_loc = np_fullmet
        elseif(ivar.eq.20)then
          write(infile,119)trim(adjustl(MR_MetStep_File(istep))), &
                           "pres.lcb.gauss.",MR_iwind5_year(istep),".nc"
        elseif(ivar.eq.21)then
          write(infile,119)trim(adjustl(MR_MetStep_File(istep))), &
                           "pres.lct.gauss.",MR_iwind5_year(istep),".nc"
        elseif(ivar.eq.30)then
          write(infile,116)trim(adjustl(MR_MetStep_File(istep))), &
                           "rhum.",MR_iwind5_year(istep),".nc"
          np_met_loc = nlevs_fullmet(Met_var_zdim_idx(ivar))
          !np_met_loc = np_fullmet_RH
        elseif(ivar.eq.31)then
          write(infile,116)trim(adjustl(MR_MetStep_File(istep))), &
                           "shum.",MR_iwind5_year(istep),".nc"
          !np_met_loc = np_fullmet_RH
          np_met_loc = nlevs_fullmet(Met_var_zdim_idx(ivar))
        elseif(ivar.eq.32)then
          write(infile,116)trim(adjustl(MR_MetStep_File(istep))), &
                           "shum.",MR_iwind5_year(istep),".nc"
          !np_met_loc = np_fullmet_RH
          np_met_loc = nlevs_fullmet(Met_var_zdim_idx(ivar))
        elseif(ivar.eq.44)then
          write(infile,118)trim(adjustl(MR_MetStep_File(istep))), &
                           "prate.lct.gauss.",MR_iwind5_year(istep),".nc"
        elseif(ivar.eq.45)then
          write(infile,118)trim(adjustl(MR_MetStep_File(istep))), &
                           "cprat.lct.gauss.",MR_iwind5_year(istep),".nc"
        else
          write(MR_global_info,*)"Requested variable not available."
          stop 1
        endif
        infile = trim(adjustl(infile))

 115    format(a50,a4,i4,a3)
 116    format(a50,a5,i4,a3)
 117    format(a50,a6,i4,a3)
 118    format(a50,a16,i4,a3)
 119    format(a50,a15,i4,a3)
      elseif(MR_iwindformat.eq.27)then
        ! Get correct file
        if(ivar.eq.1)then
          write(infile,125)trim(adjustl(MR_MetStep_File(istep))), &
                           "pgrbanl_mean_",MR_iwind5_year(istep), &
                           "_HGT_pres.nc"
          np_met_loc = np_fullmet
        elseif(ivar.eq.2)then
          write(infile,126)trim(adjustl(MR_MetStep_File(istep))), &
                           "pgrbanl_mean_",MR_iwind5_year(istep), &
                           "_UGRD_pres.nc"
          np_met_loc = np_fullmet
        elseif(ivar.eq.3)then
          write(infile,126)trim(adjustl(MR_MetStep_File(istep))), &
                           "pgrbanl_mean_",MR_iwind5_year(istep), &
                           "_VGRD_pres.nc"
          np_met_loc = np_fullmet
        elseif(ivar.eq.4)then
          write(infile,126)trim(adjustl(MR_MetStep_File(istep))), &
                           "pgrbanl_mean_",MR_iwind5_year(istep), &
                           "_VVEL_pres.nc"
          !np_met_loc = np_fullmet_Vz
          np_met_loc = nlevs_fullmet(Met_var_zdim_idx(ivar))
        elseif(ivar.eq.5)then
          write(infile,125)trim(adjustl(MR_MetStep_File(istep))), &
                           "pgrbanl_mean_",MR_iwind5_year(istep), &
                           "_TMP_pres.nc"
          np_met_loc = np_fullmet
        elseif(ivar.eq.10)then
          write(infile,128)trim(adjustl(MR_MetStep_File(istep))), &
                           "sflxgrbfg_mean_",MR_iwind5_year(istep), &
                           "_HPBL_sfc.nc"
        elseif(ivar.eq.22)then
          write(infile,130)trim(adjustl(MR_MetStep_File(istep))), &
                           "sflxgrbfg_mean_",MR_iwind5_year(istep), &
                           "_TMP_low-cldtop.nc"
        elseif(ivar.eq.23)then
          write(infile,131)trim(adjustl(MR_MetStep_File(istep))), &
                           "sflxgrbfg_mean_",MR_iwind5_year(istep), &
                           "_TCDC_low-cldlay.nc"
        elseif(ivar.eq.30)then
          write(infile,127)trim(adjustl(MR_MetStep_File(istep))), &
                           "pgrbanl_mean_",MR_iwind5_year(istep), &
                           "_RH_pres.nc"
          !np_met_loc = np_fullmet_RH
          np_met_loc = nlevs_fullmet(Met_var_zdim_idx(ivar))
        elseif(ivar.eq.44)then
          write(infile,129)trim(adjustl(MR_MetStep_File(istep))), &
                           "sflxgrbfg_mean_",MR_iwind5_year(istep), &
                           "_PRATE_sfc.nc"
        elseif(ivar.eq.45)then
          write(infile,129)trim(adjustl(MR_MetStep_File(istep))), &
                           "sflxgrbfg_mean_",MR_iwind5_year(istep), &
                           "_CPRAT_sfc.nc"
        else
          write(MR_global_info,*)"Requested variable not available."
          stop 1
        endif
        infile = trim(adjustl(infile))

 125      format(a50,a13,i4,a12)
 126      format(a50,a13,i4,a13)
 127      format(a50,a13,i4,a11)
 128      format(a50,a15,i4,a12)
 129      format(a50,a15,i4,a13)
 130      format(a50,a15,i4,a18)
 131      format(a50,a15,i4,a19)
      else  ! all other cases besides iwf25 and iwf27
        !if(ivar.eq.4)then
        !  np_met_loc = np_fullmet_Vz
        !!elseif(ivar.eq.5)then
        !!  np_met_loc = np_fullmet_T
        !elseif(ivar.eq.30)then
        !  np_met_loc = np_fullmet_RH
        !else
        !  np_met_loc = np_fullmet
        !endif

        np_met_loc = nlevs_fullmet(Met_var_zdim_idx(ivar))
          ! Files are listed directly, not through directories (as in MR_iwindformat=25,27)
        infile = trim(adjustl(MR_MetStep_File(istep)))
      endif
      invar = Met_var_names(ivar)

      write(MR_global_info,*)istep,ivar,"Reading ",trim(adjustl(invar))," from file : ",&
                trim(adjustl(infile))!,nx_submet,ny_submet,np_met_loc
      nSTAT = nf90_open(trim(adjustl(infile)),NF90_NOWRITE,ncid)

      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR open file:',infile,nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR open file:',infile,nf90_strerror(nSTAT)
        write(MR_global_error,*)trim(adjustl(infile)),NF90_NOWRITE,ncid,nSTAT
        write(MR_global_error,*)'Exiting'
        stop 1
      endif

      ! Load data variables for just the subgrid defined above
      if (wrapgrid) then
        ict        = 2
          ! index on the sub-met
        ileft(1)   = 1;         ileft(2)   = ilhalf_nx+1
        iright(1)  = ilhalf_nx; iright(2)  = nx_submet
          ! indes on the full-met
        iistart(1) = ilhalf_fm_l; iistart(2) = irhalf_fm_l
        iicount(1) = ilhalf_nx  ; iicount(2) = irhalf_nx
      else
        ict        = 1
        ileft(1)   = 1
        iright(1)  = nx_submet
        iistart(1) = istart
        iicount(1) = nx_submet
      endif

      nSTAT = nf90_inq_varid(ncid,invar,in_var_id)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: inq_varid: ',invar,nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: inq_varid: ',invar,nf90_strerror(nSTAT)
        stop 1
      endif
      nSTAT = nf90_inquire_variable(ncid, in_var_id, invar, &
                xtype = var_xtype)
      if(nSTAT.ne.NF90_NOERR)then
        write(MR_global_error,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
        write(MR_global_log  ,*)'MR ERROR: inq_variable: ',invar,nf90_strerror(nSTAT)
        stop 1
      endif

      ! Test for version 3 vs 4 NCEP files
      if(var_xtype.eq.NF90_FLOAT)then
        NC_version = 4
      elseif(var_xtype.eq.NF90_SHORT)then
        NC_version = 3
      endif

      if(Dimension_of_Variable.eq.3)then
        MR_dum3d_metP = 0.0_sp
        If(MR_iwindformat.ne.50)then
          allocate(temp3d_sp(nx_submet,ny_submet,np_met_loc,1))
        else
            ! For MR_iwindformat = 50 (WRF), we need an extra point in p
            ! Allocate auxillary array
          if(ivar.eq.1)then
                ! Geopotential lives on z-staggered grid
            allocate(temp3d_sp(nx_submet,ny_submet,np_met_loc+1,1))
            allocate(dum3d_metP_aux(nx_submet,ny_submet,np_met_loc+1,1))
          elseif(ivar.eq.2)then
                ! U wind lives on x-staggered grid
            allocate(temp3d_sp(nx_submet+1,ny_submet,np_met_loc,1))
            allocate(dum3d_metP_aux(nx_submet+1,ny_submet,np_met_loc,1))
          elseif(ivar.eq.3)then
                ! V wind lives on y-staggered grid
            allocate(temp3d_sp(nx_submet,ny_submet+1,np_met_loc,1))
            allocate(dum3d_metP_aux(nx_submet,ny_submet+1,np_met_loc,1))
          elseif(ivar.eq.4)then
                ! W wind lives on z-staggered grid
            allocate(temp3d_sp(nx_submet,ny_submet,np_met_loc+1,1))
            allocate(dum3d_metP_aux(nx_submet,ny_submet,np_met_loc+1,1))
          elseif(ivar.eq.5)then
                ! Temp lives on non-staggered grid, but we need pres. base and pert.
            allocate(temp3d_sp(nx_submet,ny_submet,np_met_loc,1))
            allocate(dum3d_metP_aux(nx_submet,ny_submet,np_met_loc,1))
          elseif(ivar.eq.6)then
                ! pressure lives on non-staggered grid, but we need base and pert.
            allocate(temp3d_sp(nx_submet,ny_submet,np_met_loc,1))
            allocate(dum3d_metP_aux(nx_submet,ny_submet,np_met_loc,1))
          endif
        endif ! MR_iwindformat.ne.50

        do i=1,ict        !read subgrid at current time step
          if(MR_iwindformat.eq.25)then
            ! NCEP reanalysis files are now NCv4 (stored as float), but the
            ! older version, NCv3 (stored as short) might still be around.
            if(i.eq.1)allocate(temp3d_short(nx_submet,ny_submet,np_met_loc,1))
            if(var_xtype.eq.NF90_FLOAT)then
              nSTAT = nf90_get_var(ncid,in_var_id,temp3d_sp(ileft(i):iright(i),:,:,:), &
                       start = (/iistart(i),jstart,1,iwstep/),       &
                       count = (/iicount(i),ny_submet,np_met_loc,1/))
              if(nSTAT.ne.NF90_NOERR)then
                write(MR_global_error,*)'MR ERROR: get_var: ',nf90_strerror(nSTAT),iicount(i),ny_submet,np_met_loc
                write(MR_global_log  ,*)'MR ERROR: get_var: ',nf90_strerror(nSTAT),iicount(i),ny_submet,np_met_loc
                stop 1
              endif
            elseif(var_xtype.eq.NF90_SHORT)then
              nSTAT = nf90_get_var(ncid,in_var_id,temp3d_short(ileft(i):iright(i),:,:,:), &
                       start = (/iistart(i),jstart,1,iwstep/),       &
                       count = (/iicount(i),ny_submet,np_met_loc,1/))
              if(nSTAT.ne.NF90_NOERR)then
                write(MR_global_error,*)'MR ERROR: get_var: ',nf90_strerror(nSTAT)
                write(MR_global_log  ,*)'MR ERROR: get_var: ',nf90_strerror(nSTAT)
                stop 1
              endif
            endif
          elseif(MR_iwindformat.eq.50)then

            ! Now read the data and convert if necessary
            if(ivar.eq.1)then
                ! Geopotential
                ! Get PHB
              nSTAT = nf90_get_var(ncid,in_var_id,temp3d_sp(ileft(i):iright(i),:,:,:), &
                       start = (/iistart(i),jstart,1,iwstep/),       &
                       count = (/iicount(i),ny_submet,np_met_loc+1,1/))
              if(nSTAT.ne.NF90_NOERR)then
                write(MR_global_error,*)'MR ERROR: get_var: PHB',nf90_strerror(nSTAT)
                write(MR_global_log  ,*)'MR ERROR: get_var: PHB',nf90_strerror(nSTAT)
                stop 1
              endif
              write(MR_global_info,*)istep,"Reading ","PH"," from file : ",trim(adjustl(infile))
              nSTAT = nf90_inq_varid(ncid,"PH",in_var_id2)
              if(nSTAT.ne.NF90_NOERR)then
                write(MR_global_error,*)'MR ERROR: inq_var: PH',nf90_strerror(nSTAT)
                write(MR_global_log  ,*)'MR ERROR: inq_var: PH',nf90_strerror(nSTAT)
                stop 1
              endif
              nSTAT = nf90_get_var(ncid,in_var_id,dum3d_metP_aux(ileft(i):iright(i),:,:,:), &
                       start = (/iistart(i),jstart,1,iwstep/),       &
                       count = (/iicount(i),ny_submet,np_met_loc+1,1/))
              if(nSTAT.ne.NF90_NOERR)then
                write(MR_global_error,*)'MR ERROR: get_var: PH',nf90_strerror(nSTAT)
                write(MR_global_log  ,*)'MR ERROR: get_var: PH',nf90_strerror(nSTAT)
                stop 1
              endif
              temp3d_sp(:,:,:,:) = temp3d_sp(:,:,:,:) + dum3d_metP_aux(:,:,:,:)
              do kk=1,np_met_loc
                MR_dum3d_metP(:,:,kk) = 0.5_sp*(temp3d_sp(:,:,kk  ,1) + &
                                          temp3d_sp(:,:,kk+1,1))
              enddo

            elseif(ivar.eq.2)then
                ! U wind lives on x-staggered grid
              nSTAT = nf90_get_var(ncid,in_var_id,temp3d_sp(ileft(i):iright(i)+1,:,:,:), &
                       start = (/iistart(i),jstart,1,iwstep/),       &
                       count = (/iicount(i)+1,ny_submet,np_met_loc,1/))
              if(nSTAT.ne.NF90_NOERR)then 
                write(MR_global_error,*)'MR ERROR: get_var: U',nf90_strerror(nSTAT)
                write(MR_global_log  ,*)'MR ERROR: get_var: U',nf90_strerror(nSTAT)
                stop 1
              endif
              do ii=1,iicount(i)
                MR_dum3d_metP(ii,:,:) = 0.5_sp*(temp3d_sp(ii  ,:,:,1) + &
                                          temp3d_sp(ii+1,:,:,1))
              enddo
            elseif(ivar.eq.3)then
                ! V wind lives on y-staggered grid
              nSTAT = nf90_get_var(ncid,in_var_id,temp3d_sp(ileft(i):iright(i),:,:,:), &
                       start = (/iistart(i),jstart,1,iwstep/),       &
                       count = (/iicount(i),ny_submet+1,np_met_loc,1/))
              if(nSTAT.ne.NF90_NOERR)then
                write(MR_global_error,*)'MR ERROR: get_var: V',nf90_strerror(nSTAT)
                write(MR_global_log  ,*)'MR ERROR: get_var: V',nf90_strerror(nSTAT)
                stop 1
              endif
              do jj=1,ny_submet
                MR_dum3d_metP(:,jj,:) = 0.5_sp*(temp3d_sp(:,jj,:,1) + &
                                          temp3d_sp(:,jj,:,1))
              enddo
            elseif(ivar.eq.4)then
                ! W wind lives on z-staggered grid
              nSTAT = nf90_get_var(ncid,in_var_id,temp3d_sp(ileft(i):iright(i),:,:,:), &
                       start = (/iistart(i),jstart,1,iwstep/),       &
                       count = (/iicount(i),ny_submet,np_met_loc+1,1/))
              if(nSTAT.ne.NF90_NOERR)then
                write(MR_global_error,*)'MR ERROR: get_var: W',nf90_strerror(nSTAT)
                write(MR_global_log  ,*)'MR ERROR: get_var: W',nf90_strerror(nSTAT)
                stop 1
              endif
              do kk=1,np_met_loc
                MR_dum3d_metP(:,:,kk) = 0.5_sp*(temp3d_sp(:,:,kk  ,1) + &
                                          temp3d_sp(:,:,kk+1,1))
              enddo
            elseif(ivar.eq.5)then
                ! Temperature is actually stored as potential temperature
                ! perturbation: we convert to potential temperature via
                !  theta = (pot.temp.pert + 300.0)
                ! and convert to thermodynamic temperature via
                !  Temp = theta*(p/p_0)^kappa
                !    where p_0   = 1000.0mb (or 1.0e5 Pa)
                !    and   kappa = R/c_p = 0.2854 (for dry air)
                ! Temp lives on non-staggered grid, but we need pres. base and pert.
                ! First get PB (base pressure)
              write(MR_global_info,*)istep,"Reading ","PB"," from file : ",trim(adjustl(infile))
              nSTAT = nf90_inq_varid(ncid,"PB",in_var_id1)
              if(nSTAT.ne.NF90_NOERR)then
                write(MR_global_error,*)'MR ERROR: inq_var: PB',nf90_strerror(nSTAT)
                write(MR_global_log  ,*)'MR ERROR: inq_var: PB',nf90_strerror(nSTAT)
                stop 1
              endif
              nSTAT = nf90_get_var(ncid,in_var_id1,temp3d_sp(ileft(i):iright(i),:,:,:), &
                       start = (/iistart(i),jstart,1,iwstep/),       &
                       count = (/iicount(i),ny_submet,np_met_loc,1/))
              if(nSTAT.ne.NF90_NOERR)then
                write(MR_global_error,*)'MR ERROR: get_var: PB',nf90_strerror(nSTAT)
                write(MR_global_log  ,*)'MR ERROR: get_var: PB',nf90_strerror(nSTAT)
                stop 1
              endif
                ! Now get P (pertubation pressure)
              write(MR_global_info,*)istep,"Reading ","P"," from file : ",trim(adjustl(infile))
              nSTAT = nf90_inq_varid(ncid,"P",in_var_id2)
              if(nSTAT.ne.NF90_NOERR)then
                write(MR_global_error,*)'MR ERROR: inq_var: P',nf90_strerror(nSTAT)
                write(MR_global_log  ,*)'MR ERROR: inq_var: P',nf90_strerror(nSTAT)
                stop 1
              endif
              nSTAT = nf90_get_var(ncid,in_var_id,dum3d_metP_aux(ileft(i):iright(i),:,:,:), &
                       start = (/iistart(i),jstart,1,iwstep/),       &
                       count = (/iicount(i),ny_submet,np_met_loc,1/))
              if(nSTAT.ne.NF90_NOERR)then
                write(MR_global_error,*)'MR ERROR: get_var: P',nf90_strerror(nSTAT)
                write(MR_global_log  ,*)'MR ERROR: get_var: P',nf90_strerror(nSTAT)
                stop 1
              endif
                ! Now get total pressure in Pa
              MR_dum3d_metP(:,:,:) = temp3d_sp(:,:,:,1) + dum3d_metP_aux(:,:,:,1)

                ! Read potential temperature perturbation
              nSTAT = nf90_get_var(ncid,in_var_id,temp3d_sp(ileft(i):iright(i),:,:,:), &
                       start = (/iistart(i),jstart,1,iwstep/),       &
                       count = (/iicount(i),ny_submet,np_met_loc,1/))
              if(nSTAT.ne.NF90_NOERR)then
                write(MR_global_error,*)'MR ERROR: get_var: T',nf90_strerror(nSTAT)
                write(MR_global_log  ,*)'MR ERROR: get_var: T',nf90_strerror(nSTAT)
                stop 1
              endif
              do ii=1,iicount(i)
                do jj=1,ny_submet
                  do kk=1,np_met_loc
                    theta = temp3d_sp(ii,jj,kk,1) + 300.0_sp
                    cofac = (MR_dum3d_metP(ii,jj,kk)*1.0e-5_sp)**(0.2854_sp)
                    MR_dum3d_metP(ii,jj,kk) = theta * cofac
                  enddo
                enddo
              enddo

            elseif(ivar.eq.6)then
                ! pressure
                ! Get PB (base pressure)
              nSTAT = nf90_get_var(ncid,in_var_id,temp3d_sp(ileft(i):iright(i),:,:,:), &
                       start = (/iistart(i),jstart,1,iwstep/),       &
                       count = (/iicount(i),ny_submet,np_met_loc,1/))
              if(nSTAT.ne.NF90_NOERR)then
                write(MR_global_error,*)'MR ERROR: get_var: PB',nf90_strerror(nSTAT)
                write(MR_global_log  ,*)'MR ERROR: get_var: PB',nf90_strerror(nSTAT)
                stop 1
              endif
                ! Get P (pertubation pressure)
              nSTAT = nf90_inq_varid(ncid,"P",in_var_id2)
              if(nSTAT.ne.NF90_NOERR)then
                write(MR_global_error,*)'MR ERROR: inq_var: P',nf90_strerror(nSTAT)
                write(MR_global_log  ,*)'MR ERROR: inq_var: P',nf90_strerror(nSTAT)
                stop 1
              endif
              nSTAT = nf90_get_var(ncid,in_var_id,dum3d_metP_aux(ileft(i):iright(i),:,:,:), &
                       start = (/iistart(i),jstart,1,iwstep/),       &
                       count = (/iicount(i),ny_submet,np_met_loc,1/))
              if(nSTAT.ne.NF90_NOERR)then
                write(MR_global_error,*)'MR ERROR: get_var: P',nf90_strerror(nSTAT)
                write(MR_global_log  ,*)'MR ERROR: get_var: P',nf90_strerror(nSTAT)
                stop 1
              endif
                ! Now get total pressure in Pa
              temp3d_sp(:,:,:,:) = temp3d_sp(:,:,:,:) + dum3d_metP_aux(:,:,:,:)
              MR_dum3d_metP(:,:,:) = temp3d_sp(:,:,:,1)
            else
            ! for any other 3d WRF variable, assume non-staggered grid

            endif

          else ! end of iwf25 (NECP) and iwf=50 (WRF) sections

            ! for any other 3d variable (non-WRF, non-NCEP/2.5 reannalysis)
            nSTAT = nf90_get_var(ncid,in_var_id,temp3d_sp(ileft(i):iright(i),:,:,:), &
                     start = (/iistart(i),jstart,1,iwstep/),       &
                     count = (/iicount(i),ny_submet,np_met_loc,1/))
            if(nSTAT.ne.NF90_NOERR)then
              write(MR_global_error,*)'MR ERROR: get_var: ',nf90_strerror(nSTAT)
              write(MR_global_error,*)i
              write(MR_global_error,*)ileft(i),iright(i)
              write(MR_global_error,*)iistart(i),jstart,1,iwstep
              write(MR_global_error,*)iicount(i),ny_submet,np_met_loc,1
              write(MR_global_log  ,*)'MR ERROR: get_var: ',nf90_strerror(nSTAT)
              stop 1
            endif
          endif
        enddo

        If(MR_iwindformat.ne.50)then
          do j=1,ny_submet
            itmp = ny_submet-j+1
            !reverse the j indices (since they increment from N to S)
            if(MR_iwindformat.eq.25)then
              if(var_xtype.eq.NF90_FLOAT)then
                  ! No scaling/offset needed
                MR_dum3d_metP(1:nx_submet,j,1:np_met_loc) = &
                                      real(temp3d_sp(:,itmp,:,1),kind=sp)
              elseif(var_xtype.eq.NF90_SHORT)then
                  ! NC_version = 3 :: need to scale and offset shorts to get float
                MR_dum3d_metP(1:nx_submet,j,1:np_met_loc) = &
                                      real(temp3d_short(1:nx_submet,itmp,1:np_met_loc,1),kind=sp) * &
                                    iwf25_scale_facs(ivar) + iwf25_offsets(ivar)
              endif
            else
              if(y_inverted)then
                MR_dum3d_metP(1:nx_submet,j,1:np_met_loc)  = temp3d_sp(1:nx_submet,itmp,1:np_met_loc,1)
              else
                MR_dum3d_metP(1:nx_submet,j,1:np_met_loc)  = temp3d_sp(1:nx_submet,j,1:np_met_loc,1)
              endif
            endif
          enddo
          if(z_inverted)then ! reverse the vertical coordinate
            temp3d_sp(1:nx_submet,1:ny_submet,1:np_met_loc,1) = MR_dum3d_metP(1:nx_submet,1:ny_submet,1:np_met_loc)
            do i=1,np_met_loc
              itmp = np_met_loc-i+1
              MR_dum3d_metP(1:nx_submet,1:ny_submet,i) = temp3d_sp(1:nx_submet,1:ny_submet,itmp,1)
            enddo
          endif
        endif !MR_iwindformat.eq.50, MR_iwindformat.eq.25, else

        if(MR_iwindformat.eq.25)then
          deallocate(temp3d_short)
        endif
        if(MR_iwindformat.eq.50)then
          deallocate(dum3d_metP_aux)
        endif
        deallocate(temp3d_sp)

      elseif(Dimension_of_Variable.eq.2)then
        if(IsCatagorical)then
          allocate(temp2d_int(nx_submet,ny_submet,1))
          do i=1,ict        !read subgrid at current time step
            if(MR_iwindformat.eq.25)then
              ! No catagorical variables for MR_iwindformat = 25
            else
              nSTAT = nf90_get_var(ncid,in_var_id,temp2d_int(ileft(i):iright(i),:,:), &
                         start = (/iistart(i),jstart,iwstep/),       &
                         count = (/iicount(i),ny_submet,1/))
              do j=1,ny_submet
                itmp = ny_submet-j+1
                if(y_inverted)then
                  MR_dum2d_met_int(1:nx_submet,j)  = temp2d_int(1:nx_submet,itmp,1)
                else
                  MR_dum2d_met_int(1:nx_submet,j)  = temp2d_int(1:nx_submet,j,1)
                endif
              enddo
            endif
            if(nSTAT.ne.NF90_NOERR)then
               write(MR_global_error,*)'MR ERROR: get_var:Vx ',invar,nf90_strerror(nSTAT)
               write(MR_global_log  ,*)'MR ERROR: get_var:Vx ',invar,nf90_strerror(nSTAT)
               stop 1
             endif
          enddo
          deallocate(temp2d_int)
        else
          allocate(temp2d_sp(nx_submet,ny_submet,1))
          if(ivar.eq.11.or.ivar.eq.12)then
              ! Surface winds usually have a z coordinate as well
            allocate(temp3d_sp(nx_submet,ny_submet,1,1))
          endif
  
          do i=1,ict        !read subgrid at current time step
            if(MR_iwindformat.eq.25)then
              allocate(tmpsurf2d_short(192,94,1))
              if(NC_version.eq.4)then
                nSTAT = nf90_get_var(ncid,in_var_id,temp2d_sp(:,:,1), &
                         start = (/1,1,iwstep/),       &
                         count = (/192,94,1/))
                if(nSTAT.ne.NF90_NOERR)then
                   write(MR_global_error,*)'MR ERROR: get_var: ',invar,nf90_strerror(nSTAT)
                   write(MR_global_log  ,*)'MR ERROR: get_var: ',invar,nf90_strerror(nSTAT)
                   stop 1
                endif
                write(MR_global_info,*)"Need to write interp_iwf25_grid for float"
                stop 1
                call MR_interp_iwf25_grid(nx_submet,ny_submet,tmpsurf2d_short,temp2d_sp,&
                                    iwf25_scale_facs(ivar),iwf25_offsets(ivar))
                MR_dum2d_met(1:nx_submet,:) = temp2d_sp(1:nx_submet,:,1)
              else
                nSTAT = nf90_get_var(ncid,in_var_id,tmpsurf2d_short(:,:,1), &
                         start = (/1,1,iwstep/),       &
                         count = (/192,94,1/))
                if(nSTAT.ne.NF90_NOERR)then
                   write(MR_global_error,*)'MR ERROR: get_var: ',invar,nf90_strerror(nSTAT)
                   write(MR_global_log  ,*)'MR ERROR: get_var: ',invar,nf90_strerror(nSTAT)
                   stop 1
                endif
                call MR_interp_iwf25_grid(nx_submet,ny_submet,tmpsurf2d_short,temp2d_sp,&
                                    iwf25_scale_facs(ivar),iwf25_offsets(ivar))
                MR_dum2d_met(1:nx_submet,:) = temp2d_sp(1:nx_submet,:,1)
              endif
            else
              ! 2d variables for iwf .ne. 25
              if(ivar.eq.11.or.ivar.eq.12)then
                ! Surface velocities do have a z dimension
                nSTAT = nf90_get_var(ncid,in_var_id,temp3d_sp(ileft(i):iright(i),:,:,:), &
                         start = (/iistart(i),jstart,1,iwstep/),       &
                         count = (/iicount(i),ny_submet,1,1/))
                if(nSTAT.ne.NF90_NOERR)then
                   write(MR_global_error,*)'MR ERROR: get_var: ',invar,nf90_strerror(nSTAT)
                   write(MR_global_log  ,*)'MR ERROR: get_var: ',invar,nf90_strerror(nSTAT)
                   stop 1
                endif
                do j=1,ny_submet
                  itmp = ny_submet-j+1
                  if(y_inverted)then
                    MR_dum2d_met(1:nx_submet,j)  = temp3d_sp(1:nx_submet,itmp,1,1)
                  else
                    MR_dum2d_met(1:nx_submet,j)  = temp3d_sp(1:nx_submet,j,1,1)
                  endif
                enddo
              else
                nSTAT = nf90_get_var(ncid,in_var_id,temp2d_sp(ileft(i):iright(i),:,:), &
                         start = (/iistart(i),jstart,iwstep/),       &
                         count = (/iicount(i),ny_submet,1/))
                if(nSTAT.ne.NF90_NOERR)then
                   write(MR_global_error,*)'MR ERROR: get_var: ',invar,nf90_strerror(nSTAT)
                   write(MR_global_log  ,*)'MR ERROR: get_var: ',invar,nf90_strerror(nSTAT)
                   stop 1
                endif
                do j=1,ny_submet
                  itmp = ny_submet-j+1
                  if(y_inverted)then
                    MR_dum2d_met(1:nx_submet,j)  = temp2d_sp(1:nx_submet,itmp,1)
                  else
                    MR_dum2d_met(1:nx_submet,j)  = temp2d_sp(1:nx_submet,j,1)
                  endif
                enddo
              endif
            endif
          enddo
          deallocate(temp2d_sp)
          if(ivar.eq.11.or.ivar.eq.12) deallocate(temp3d_sp)
          if(MR_iwindformat.eq.25) deallocate(tmpsurf2d_short)
        endif ! IsCatagorical
      endif ! Dimension_of_Variable.eq.2

      if(ivar.eq.1)then
        ! If this is filling HGT, then we need to do a special QC check
        !if(MR_iwindformat.eq.24)then
          ! It seems like only NASA has NaNs for pressures greater than surface
          ! pressure
          do i=1,nx_submet
            do j=1,ny_submet
              do k=1,np_met_loc
                if(MR_dum3d_metP(i,j,k).gt.1.0e10_sp)then
                   ! linearly interpolate in z
                   ! find the first non NaN above k
                   do kk = k+1,np_met_loc,1
                     if(MR_dum3d_metP(i,j,kk).lt.1.0e10_sp)exit
                   enddo
                   if(kk.eq.np_met_loc+1)then
                     kk=np_met_loc
                     MR_dum3d_metP(i,j,kk) = 0.0_sp
                   endif
                   ! find the first non NaN below k if k!=1
                   do kkk = max(k-1,1),1,-1
                     if(MR_dum3d_metP(i,j,kkk).lt.1.0e10_sp)exit
                   enddo
                   if(kkk.eq.0)then
                     kkk=1
                     MR_dum3d_metP(i,j,kkk) = 0.0_sp
                   endif
                   MR_dum3d_metP(i,j,k) = MR_dum3d_metP(i,j,kkk) + &
                         (MR_dum3d_metP(i,j,kk)-MR_dum3d_metP(i,j,kkk)) * &
                         real(k-kkk,kind=sp)/real(kk-kkk,kind=sp)
                endif
              enddo
            enddo
          enddo
        !endif
        ! convert m to km
        MR_dum3d_metP = MR_dum3d_metP / 1000.0_sp
      elseif(Dimension_of_Variable.eq.3)then
        ! Do QC checking of all other 3d variables
        If(ivar.eq.2.or.ivar.eq.3.or.ivar.eq.4)then
          ! taper winds (vx,vy,vz) to zero at ground surface
          if(istep.eq.MR_iMetStep_Now)then
            call MR_QC_3dvar(ivar,nx_submet,ny_submet,np_fullmet,MR_geoH_metP_last,       &
                          np_met_loc,MR_dum3d_metP,fill_value_sp(MR_iwindformat), &
                          bc_low_sp=0.0_sp)
          else
            call MR_QC_3dvar(ivar,nx_submet,ny_submet,np_fullmet,MR_geoH_metP_next,       &
                          np_met_loc,MR_dum3d_metP,fill_value_sp(MR_iwindformat), &
                          bc_low_sp=0.0_sp)
          endif
        elseif(ivar.eq.5)then
          ! set ground and top-level conditions for temperature
          idx = Met_var_zdim_idx(ivar)
          pp = levs_fullmet_sp(idx,nlevs_fullmet(idx))/real(100.0,kind=sp)
          Z_top = MR_Z_US_StdAtm(pp)
          T_top = MR_Temp_US_StdAtm(Z_top)
          if(istep.eq.MR_iMetStep_Now)then
            call MR_QC_3dvar(ivar,nx_submet,ny_submet,np_fullmet,MR_geoH_metP_last,       &
                          np_met_loc,MR_dum3d_metP,fill_value_sp(MR_iwindformat), &
                          bc_low_sp=293.0_sp, bc_high_sp=T_top)
          else
            call MR_QC_3dvar(ivar,nx_submet,ny_submet,np_fullmet,MR_geoH_metP_next,       &
                          np_met_loc,MR_dum3d_metP,fill_value_sp(MR_iwindformat), &
                          bc_low_sp=293.0_sp, bc_high_sp=T_top)
          endif
        else
          ! For other variables, use the top and bottom non-fill values
          if(istep.eq.MR_iMetStep_Now)then
            call MR_QC_3dvar(ivar,nx_submet,ny_submet,np_fullmet,MR_geoH_metP_last,       &
                          np_met_loc,MR_dum3d_metP,fill_value_sp(MR_iwindformat))
          else
            call MR_QC_3dvar(ivar,nx_submet,ny_submet,np_fullmet,MR_geoH_metP_next,       &
                          np_met_loc,MR_dum3d_metP,fill_value_sp(MR_iwindformat))
          endif
        endif
      endif

      if(ivar.eq.4)then
        if(MR_iwindformat.ne.50)then
            ! For pressure vertical velocity, convert from Pa s to m/s by dividing
            ! by pressure gradient
          idx = Met_var_zdim_idx(ivar)
          do k=1,np_met_loc
            do i=1,nx_submet
              do j=1,ny_submet
                if(k.eq.1)then
                  ! Use one-sided gradients for bottom
                  del_p = levs_fullmet_sp(idx,2) - levs_fullmet_sp(idx,1)
                  !del_P = p_fullmet_Vz_sp(2)-p_fullmet_Vz_sp(1)
                  if(istep.eq.MR_iMetStep_Now)then
                    del_H = MR_geoH_metP_last(i,j,2) - MR_geoH_metP_last(i,j,1)
                  else
                    del_H = MR_geoH_metP_next(i,j,2) - MR_geoH_metP_next(i,j,1)
                  endif
                elseif(k.eq.np_met_loc)then
                  ! Use one-sided gradients for top
                  !del_P = p_fullmet_Vz_sp(np_met_loc) - &
                  !         p_fullmet_Vz_sp(np_met_loc-1)
                  del_p = levs_fullmet_sp(idx,nlevs_fullmet(idx)) - &
                          levs_fullmet_sp(idx,nlevs_fullmet(idx)-1)
                  if(istep.eq.MR_iMetStep_Now)then
                    del_H = MR_geoH_metP_last(i,j,np_met_loc) - &
                             MR_geoH_metP_last(i,j,np_met_loc-1)
                  else
                    del_H = MR_geoH_metP_next(i,j,np_met_loc) - &
                             MR_geoH_metP_next(i,j,np_met_loc-1)
                  endif
                else
                  ! otherwise, two-sided calculation
                  !del_P = p_fullmet_Vz_sp(k+1)-p_fullmet_Vz_sp(k-1)
                  del_p = levs_fullmet_sp(idx,k+1) - &
                          levs_fullmet_sp(idx,k)
                  if(istep.eq.MR_iMetStep_Now)then
                    del_H = MR_geoH_metP_last(i,j,k+1) - MR_geoH_metP_last(i,j,k-1)
                  else
                    del_H = MR_geoH_metP_next(i,j,k+1) - MR_geoH_metP_next(i,j,k-1)
                  endif
                endif
                del_H = del_H * 1000.0_sp ! convert to m
                if(abs(del_H).gt.MR_EPS_SMALL)then
                  dpdz  = del_P/del_H
                else
                  write(MR_global_error,*)'MR ERROR: failed to calculate dpdz'
                  write(MR_global_error,*)i,j,k,del_P,del_H
                  write(MR_global_error,*)MR_geoH_metP_last(i,j,:)
                  stop 1
                endif
                MR_dum3d_metP(i,j,k) = MR_dum3d_metP(i,j,k) / dpdz
              enddo ! j
            enddo ! i
          enddo ! k
        endif
      endif

      MR_dum3d_metP = MR_dum3d_metP * Met_var_conversion_factor(ivar)

      end subroutine MR_Read_MetP_Variable_netcdf

!##############################################################################
!
!    MR_interp_iwf25_grid
!
!##############################################################################

      subroutine MR_interp_iwf25_grid(imax,jmax,invar,outvar,scale_fac,offset)

      use MetReader

      implicit none

      integer, parameter :: sp        = 4 ! single precision
      integer, parameter :: dp        = 8 ! double precision

      integer         ,intent(in)  :: imax,jmax
      integer(kind=sp),intent(in)  :: invar(192,94,1)
      real(kind=sp)   ,intent(out) :: outvar(imax,jmax)
      real(kind=sp)   ,intent(in)  :: scale_fac
      real(kind=sp)   ,intent(in)  :: offset

      real(kind=sp)    :: a1,a2,a3,a4
      real(kind=sp)    :: v1,v2,v3,v4

      integer :: ilon,ilat

      do ilon = 1,imax
        do ilat = 1,jmax
          a1 = amap_iwf25(ilon,ilat,1)
          a2 = amap_iwf25(ilon,ilat,2)
          a3 = amap_iwf25(ilon,ilat,3)
          a4 = amap_iwf25(ilon,ilat,4)
          v1 = invar(imap_iwf25(ilon,ilat,1),imap_iwf25(ilon,ilat,3),1) &
                 * scale_fac + offset
          v2 = invar(imap_iwf25(ilon,ilat,2),imap_iwf25(ilon,ilat,3),1) &
                 * scale_fac + offset
          v3 = invar(imap_iwf25(ilon,ilat,2),imap_iwf25(ilon,ilat,4),1) &
                 * scale_fac + offset
          v4 = invar(imap_iwf25(ilon,ilat,1),imap_iwf25(ilon,ilat,4),1) &
                 * scale_fac + offset

          outvar(ilon,ilat) = a1*v1 + a2*v2 + a3*v3 + a4*v4
        enddo
      enddo

      end subroutine MR_interp_iwf25_grid


