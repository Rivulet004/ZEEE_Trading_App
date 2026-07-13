from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.db import transaction
from .models import Company, CompanyLocation

User = get_user_model()

class CompanyLocationSerializer(serializers.ModelSerializer):
    class Meta:
        model = CompanyLocation
        fields = ['location_name', 'delivery_address', 'zip_code', 'sales_tax_id']


class EnterpriseRegisterSerializer(serializers.ModelSerializer):
    """
    Enterprise-scale registration serializer.
    Processes a nested JSON payload to construct a Company, its first Shipping Location, 
    and the administrative owner account inside a single atomic database transaction.
    """
    password = serializers.CharField(write_only=True, required=True, style={'input_type': 'password'})
    
    # Accept structural nested location and company parameters inside the registration packet
    company_name = serializers.CharField(write_only=True, required=True)
    corporate_email = serializers.EmailField(write_only=True, required=True)
    location_data = CompanyLocationSerializer(write_only=True, required=True)

    class Meta:
        model = User
        fields = ['username', 'password', 'email', 'first_name', 'last_name', 'company_name', 'corporate_email', 'location_data']

    def validate_email(self, value):
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("An agent account with this email address already exists.")
        return value

    def create(self, validated_data):
        # Extract our nested corporate structural assets from the validated dictionary object
        company_name = validated_data.pop('company_name')
        corporate_email = validated_data.pop('corporate_email')
        location_json = validated_data.pop('location_data')
        password = validated_data.pop('password')

        # Use an atomic transaction block. If any single table write fails, 
        # the database rolls back completely to prevent corrupt orphan records.
        with transaction.atomic():
            # 1. Instantiate the corporate entity layer
            company = Company.objects.create(
                legal_name=company_name,
                corporate_email=corporate_email
            )

            # 2. Map the initial physical shipping address and Tax ID mapping rules
            CompanyLocation.objects.create(
                company=company,
                location_name=location_json.get('location_name', 'Primary Branch'),
                delivery_address=location_json['delivery_address'],
                zip_code=location_json['zip_code'],
                sales_tax_id=location_json['sales_tax_id']
            )

            # 3. Instantiate the human user agent, binding them directly as the Company Admin
            user = User.objects.create_user(
                company=company,
                role=User.UserRoles.ADMIN,
                password=password,
                **validated_data
            )
            
        return user


class UserProfileSerializer(serializers.ModelSerializer):
    """ Used to serve clean profile overviews down to the mobile client upon verification checks """
    company_name = serializers.CharField(source='company.legal_name', read_only=True)
    
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 'role', 'company_name']