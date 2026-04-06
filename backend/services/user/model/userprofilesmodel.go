package model

import (
	"github.com/zeromicro/go-zero/core/stores/cache"
	"github.com/zeromicro/go-zero/core/stores/sqlx"
)

var _ UserProfilesModel = (*customUserProfilesModel)(nil)

type (
	// UserProfilesModel is an interface to be customized, add more methods here,
	// and implement the added methods in customUserProfilesModel.
	UserProfilesModel interface {
		userProfilesModel
	}

	customUserProfilesModel struct {
		*defaultUserProfilesModel
	}
)

// NewUserProfilesModel returns a model for the database table.
func NewUserProfilesModel(conn sqlx.SqlConn, c cache.CacheConf, opts ...cache.Option) UserProfilesModel {
	return &customUserProfilesModel{
		defaultUserProfilesModel: newUserProfilesModel(conn, c, opts...),
	}
}
