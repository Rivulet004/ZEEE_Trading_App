from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView
from django.contrib.auth.forms import PasswordResetForm

# Import the new, nested B2B data translators we designed
from .serializers import (
    EnterpriseRegisterSerializer,
    UserProfileSerializer,
    CustomTokenObtainPairSerializer,
)

class EnterpriseRegisterView(APIView):
    """
    Handles B2B corporate self-registration requests.
    Using an atomic transaction behind the scenes, it creates a Company entity,
    maps their first physical Shipping Location, hashes the admin password,
    and returns a clean pair of short-lived Access and long-lived Refresh JWTs.
    """
    def post(self, request):
        # Bind the incoming multi-tier JSON data payload to our enterprise registration engine
        serializer = EnterpriseRegisterSerializer(data=request.data)
        
        if serializer.is_valid():
            # Save the models safely to PostgreSQL/SQLite tables
            user = serializer.save()
            
            # Programmatically generate high-security JWT token matrices for the brand new user
            refresh = RefreshToken.for_user(user)
            
            return Response({
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": UserProfileSerializer(user).data,
                "message": "Enterprise commercial portal and administrator profile successfully initialized."
            }, status=status.HTTP_201_CREATED)
            
        # If input structural validations fail, spit out clean diagnostic validation arrays
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class CustomTokenObtainPairView(TokenObtainPairView):
    """
    Enhanced login view inheriting from SimpleJWT's native framework.
    Validates credentials and returns tokens plus the authenticated user profile
    from the serializer's already-resolved user instance.
    """
    serializer_class = CustomTokenObtainPairSerializer


class CheckTokenView(APIView):
    """
    An isolated security validation checkpoint gateway.
    Allows the Flutter mobile UI to ping the server instantly on application cold start
    to check if an existing cached Access token is still valid.
    """
    # Restricts passage exclusively to requests carrying a valid 'Authorization: Bearer <JWT>' header
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # request.user is automatically populated by SimpleJWT if the header decrypts cleanly
        serializer = UserProfileSerializer(request.user)
        return Response({
            "authenticated": True,
            "user": serializer.data
        }, status=status.HTTP_200_OK)


class PasswordResetRequestView(APIView):
    """
    Receives email parameters and generates cryptographic recovery signatures.
    Outputs cleartext links directly into the terminal window during local development iterations.
    """
    def post(self, request):
        form = PasswordResetForm(request.data)
        if form.is_valid():
            # Internal engine checks if account exists, calculates expiration tokens,
            # and pipes the compiled recovery body out to the active email template files.
            # Protocol follows the incoming request (https when the connection is secure).
            form.save(
                request=request,
                use_https=request.is_secure(),
                email_template_name='registration/password_reset_email.html',
                subject_template_name='registration/password_reset_subject.txt'
            )
            return Response({
                "message": "If this account exists in our commercial register, a recovery link has been generated."
            }, status=status.HTTP_200_OK)
            
        return Response(form.errors, status=status.HTTP_400_BAD_REQUEST)