!$Id$
#include"cppdefs.h"
!-----------------------------------------------------------------------
!BOP
!
! !MODULE: wave --- wave calculation \label{sec:wave}
!
! !INTERFACE:
   module wave
!
! !DESCRIPTION:
!  Wave calculation
!
!  Contains main switch box
!  to various wave calculation methods
!
!  currently contains simple JONSWAP equilibrium wave method
!
!
! @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
!
!
! @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
!
! !USES:

!
!  default: all is private.
!   private
!
! !PUBLIC MEMBER FUNCTIONS:
!   public do_wave
   public
!
! !PRIVATE MEMBER FUNCTIONS:

!
! !REVISION HISTORY:
!  Original author(s): Johan Van Der Molen 
!
! Nov 2013: taken from  gotm-3.3.2_withspm_may2011 without modifications
!
!  $Log$
!
! !LOCAL VARIABLES:

!EOP
!-----------------------------------------------------------------------

   contains

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: Manages SPM equations
!
! !INTERFACE:
   subroutine do_wave(wave_mode,Hhs,Ttz,Phiw,wind,windx,windy,depth)
!
! !DESCRIPTION:
!  This routine is the main switch box that selects the method
!  to determine spm concentrations
!
! !USES:
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   integer, intent(in)                 :: wave_mode
   REALTYPE, intent(in)                 :: wind,windx,windy,depth
   REALTYPE, intent(out)                :: Hhs,Ttz,Phiw
!
! !REVISION HISTORY:
!  Original author(s): Hans Burchard 
!
! !LOCAL VARIABLES

!EOP
!-----------------------------------------------------------------------
!BOC

! establish wave conditions

   select case (wave_mode)
   case (1)   ! simple JONSWAP equilibrium model
     call jonswap(Hhs,Ttz,Phiw,wind,windx,windy,depth)
   case default
     stop
!JM error message here
   end select

   return
   end subroutine do_wave
!EOC

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: Calculate wave conditions using JONWAP method
!
! !INTERFACE:
   subroutine jonswap(Hhs,Ttz,Phiw,wind,windx,windy,depth)
!
! !DESCRIPTION:
! Calculates wave characteristics assuming equilibrium with wind and JONSWAP spectrum
!
! !USES:
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   REALTYPE, intent(in)                 :: wind,windx,windy,depth
   REALTYPE, intent(out)                :: Hhs,Ttz,Phiw
!

! !LOCAL VARIABLES
   REALTYPE, parameter  :: g=9.81 
   REALTYPE             :: U,F,Fstar,Td,Tdm
   REALTYPE, parameter :: pi=3.141592654, d360=360.0
!JM Tuning params: could come in through namelist in future
!CGIANNOP MODIFICATION 2026/09/03
!   REALTYPE, parameter  :: Hs_min=0.0, Tz_min=1.0, Tdmax=3*3600 
   REALTYPE, parameter  :: Hs_min=0.0, Tz_min=0.1, Tdmax=3*3600 
!CGIANNOP
!EOP
!-----------------------------------------------------------------------
!BOC
   
   if (wind.gt.1E-3) then
     ! assume reduced duration in shallow water
     if (depth.lt.10.0) then 
       Tdm=((depth/10.0)**2)*Tdmax
     else
       Tdm=Tdmax
     endif
     ! simple wave generation: vRijn p 331
     F=wind*Tdm                        ! fetch
     U=0.7*(wind**1.2)
     Fstar=g*F/(U**2)
     Td=68.8*(Fstar**0.67)*U/g
     Hhs=max(Hs_min,min(0.243*(U**2)/g,0.0016*sqrt(Fstar)*(U**2)/g))
     Hhs=min(Hhs,0.4*depth)
     Ttz=max(Tz_min,min(8.14*U/g,0.286*(Fstar**0.33)*U/g))

     Phiw=atan2(windy,windx)
     if (Phiw .lt. _ZERO_) then       ! degrees wrt North
        Phiw=180.*(pi/2-Phiw)/pi
     else
        Phiw=180.*(2*pi-(Phiw-pi/2))/pi
     end if
     Phiw=mod(Phiw,d360)             ! reduce to <360

   else
     Hhs=0.0
     Ttz=Tz_min
     Phiw=0.0
   endif

   return
   end subroutine jonswap
!EOC


   end module wave

!-----------------------------------------------------------------------
! Copyright by the GOTM-team under the GNU Public License - www.gnu.org
!-----------------------------------------------------------------------
